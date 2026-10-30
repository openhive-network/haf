-- Advisory-lock coordination between HAF app installers and block-processors.
--
-- Block-processors hold a SHARED advisory lock on each app they depend on
-- (including themselves) for the lifetime of their main-loop session.
-- Installers TRY an EXCLUSIVE advisory lock on the app they install; if any
-- shared holder exists, the installer skips its work and exits cleanly.
--
-- Both sides first check that the app's registered process procedure
-- (hafd.applications, keyed by the same name as the lock) still resolves. A
-- holder of a broken app's lock cannot be doing useful processing, so the
-- installer does not skip: it waits briefly for the holders to go, then fails
-- naming them. A block-processor refuses to keep the lock of a broken app, so a
-- crash-looping loop never blocks its own repair.
--
-- Callers must `SET application_name` before invoking these so the holder
-- descriptions returned on contention are human-readable.


CREATE OR REPLACE FUNCTION hive._try_app_lock( _app_name TEXT, _exclusive BOOLEAN )
    RETURNS TEXT
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __classid INTEGER := hashtext( 'hive_fork_manager_app_lock' );
    __objid   INTEGER := hashtext( _app_name );
    __acquired BOOLEAN;
    __holders TEXT;
BEGIN
    IF _exclusive THEN
        __acquired := pg_try_advisory_lock( __classid, __objid );
    ELSE
        __acquired := pg_try_advisory_lock_shared( __classid, __objid );
    END IF;

    IF __acquired THEN
        RETURN NULL;
    END IF;

    SELECT string_agg( format( '%s (pid=%s)', a.application_name, a.pid ), ', ' )
      INTO __holders
      FROM pg_locks l
      JOIN pg_stat_activity a ON a.pid = l.pid
     WHERE l.locktype = 'advisory'
       AND l.classid  = __classid
       AND l.objid    = __objid
       AND l.granted;

    RETURN COALESCE( __holders, '(unknown)' );
END;
$BODY$
;


-- The app's registered process procedure when it no longer resolves; NULL for a
-- healthy, self-driven or unregistered app.
CREATE OR REPLACE FUNCTION hive._missing_app_process_procedure( _app_name TEXT )
    RETURNS TEXT
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __procedure TEXT;
BEGIN
    SELECT a.process_procedure INTO __procedure
    FROM hafd.applications a
    WHERE a.name = _app_name;

    IF __procedure IS NULL OR to_regprocedure( __procedure || '( hive.blocks_range )' ) IS NOT NULL THEN
        RETURN NULL;
    END IF;
    RETURN __procedure;
EXCEPTION WHEN insufficient_privilege THEN
    -- A dependent's role need not have USAGE on the schema of the app it depends on;
    -- unable to tell, it is treated as healthy, as before this check existed.
    RETURN NULL;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.try_acquire_app_install_lock( _app_name TEXT )
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __holders TEXT;
    __missing TEXT;
    __deadline TIMESTAMPTZ;
BEGIN
    __holders := hive._try_app_lock( _app_name, TRUE );
    IF __holders IS NULL THEN
        RETURN TRUE;
    END IF;

    __missing := hive._missing_app_process_procedure( _app_name );
    IF __missing IS NULL THEN
        RAISE NOTICE 'Skipping install: lock on % held by %', _app_name, __holders;
        RETURN FALSE;
    END IF;

    -- A block-processor starting up holds a broken app's lock only until it notices
    -- the missing procedure, so give such holders a moment to let go.
    RAISE NOTICE 'Waiting for lock on %: held by % while its process procedure %( hive.blocks_range ) does not exist',
                 _app_name, __holders, __missing;
    __deadline := clock_timestamp() + interval '10 seconds';
    WHILE clock_timestamp() < __deadline LOOP
        PERFORM pg_sleep( 0.5 );
        __holders := hive._try_app_lock( _app_name, TRUE );
        IF __holders IS NULL THEN
            RETURN TRUE;
        END IF;
    END LOOP;

    RAISE EXCEPTION 'Cannot install %: its process procedure %( hive.blocks_range ) does not exist and its lock is held by %; stop those sessions and rerun the install',
                    _app_name, __missing, __holders;
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.acquire_app_block_processor_locks( _app_names TEXT[] )
    RETURNS VOID
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __app TEXT;
    __holders TEXT;
    __wait_start TIMESTAMPTZ;
    __last_log   TIMESTAMPTZ;
    __missing    TEXT;
    __locked     TEXT;
BEGIN
    FOREACH __app IN ARRAY _app_names LOOP
        __wait_start := NULL;
        LOOP
            __holders := hive._try_app_lock( __app, FALSE );
            EXIT WHEN __holders IS NULL;

            IF __wait_start IS NULL THEN
                RAISE NOTICE 'Waiting for advisory lock on %: held by %', __app, __holders;
                __wait_start := clock_timestamp();
                __last_log   := __wait_start;
            ELSIF clock_timestamp() - __last_log > interval '1 minute' THEN
                RAISE NOTICE 'Still waiting for advisory lock on %: held by %, total wait %',
                             __app, __holders, clock_timestamp() - __wait_start;
                __last_log := clock_timestamp();
            END IF;

            PERFORM pg_sleep( 1 );
        END LOOP;
    END LOOP;

    -- Checked under the locks, so an install in progress is waited for, not failed on.
    -- Advisory locks survive the error, hence the explicit release.
    FOREACH __app IN ARRAY _app_names LOOP
        __missing := hive._missing_app_process_procedure( __app );
        IF __missing IS NOT NULL THEN
            FOREACH __locked IN ARRAY _app_names LOOP
                PERFORM pg_advisory_unlock_shared( hashtext( 'hive_fork_manager_app_lock' ), hashtext( __locked ) );
            END LOOP;
            RAISE EXCEPTION 'Cannot take block-processor lock on %: its process procedure %( hive.blocks_range ) does not exist; reinstall the application',
                            __app, __missing;
        END IF;
    END LOOP;
END;
$BODY$
;
