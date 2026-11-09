-- Advisory-lock coordination between HAF app installers and block-processors.
--
-- Block-processors hold a SHARED advisory lock on each app they depend on
-- (including themselves) for the lifetime of their main-loop session.
-- Installers TRY an EXCLUSIVE advisory lock on the app they install; if any
-- shared holder exists, the installer skips its work and exits cleanly.
--
-- Both sides first check that the app's installation is not broken
-- (hive._app_broken_reason on its hafd.applications row, which an app registers
-- under the name of its lock). A holder of a broken app's lock cannot be doing
-- useful processing, so the installer does not skip: it waits briefly for the
-- holders to go, then fails naming them. A block-processor refuses to keep the
-- lock of a broken app, so a crash-looping loop never blocks its own repair.
-- An installer whose app has no row at all waits the same, then proceeds without
-- the lock; block-processors do take the lock of an app not registered yet.
--
-- Installers of an app are serialized by a separate per-app installer lock, which
-- block-processors never take: an installer takes it first and keeps it for as
-- long as the app lock, so that one proceeding without the app lock still keeps a
-- second installer out. An installer that finds it held skips its work.
--
-- Callers must `SET application_name` before invoking these so the holder
-- descriptions returned on contention are human-readable.


CREATE OR REPLACE FUNCTION hive._try_advisory_lock( _classid INTEGER, _objid INTEGER, _exclusive BOOLEAN )
    RETURNS TEXT
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __acquired BOOLEAN;
    __holders TEXT;
BEGIN
    IF _exclusive THEN
        __acquired := pg_try_advisory_lock( _classid, _objid );
    ELSE
        __acquired := pg_try_advisory_lock_shared( _classid, _objid );
    END IF;

    IF __acquired THEN
        RETURN NULL;
    END IF;

    SELECT string_agg( format( '%s (pid=%s)', a.application_name, a.pid ), ', ' )
      INTO __holders
      FROM pg_locks l
      JOIN pg_stat_activity a ON a.pid = l.pid
     WHERE l.locktype = 'advisory'
       AND l.classid  = _classid
       AND l.objid    = _objid
       AND l.granted;

    RETURN COALESCE( __holders, '(unknown)' );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive._try_app_lock( _app_name TEXT, _exclusive BOOLEAN )
    RETURNS TEXT
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    RETURN hive._try_advisory_lock( hashtext( 'hive_fork_manager_app_lock' ), hashtext( _app_name ), _exclusive );
END;
$BODY$
;


-- Why the app registered under _app_name is broken: its process procedure or
-- completed block function no longer resolves, or its health function reports a
-- reason or fails. NULL for a healthy or unregistered app.
CREATE OR REPLACE FUNCTION hive._app_broken_reason( _app_name TEXT )
    RETURNS TEXT
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __app RECORD;
    __health REGPROCEDURE;
    __reason TEXT;
BEGIN
    SELECT a.process_procedure, a.completed_block_function, a.health_function INTO __app
    FROM hafd.applications a
    WHERE a.name = _app_name;

    IF __app.process_procedure IS NOT NULL AND to_regprocedure( __app.process_procedure || '( hive.blocks_range )' ) IS NULL THEN
        RETURN format( 'its process procedure %s( hive.blocks_range ) does not exist', __app.process_procedure );
    END IF;

    IF __app.completed_block_function IS NOT NULL AND to_regprocedure( __app.completed_block_function || '()' ) IS NULL THEN
        RETURN format( 'its completed block function %s() does not exist', __app.completed_block_function );
    END IF;

    IF __app.health_function IS NULL THEN
        RETURN NULL;
    END IF;
    __health := to_regprocedure( __app.health_function || '()' );
    IF __health IS NULL THEN
        RETURN format( 'its health function %s() does not exist', __app.health_function );
    END IF;
    IF NOT has_function_privilege( __health, 'EXECUTE' ) THEN
        RETURN NULL;
    END IF;

    BEGIN
        EXECUTE format( 'SELECT %s()', __health::OID::REGPROC ) INTO __reason;
    EXCEPTION WHEN OTHERS THEN
        RETURN format( 'its health function %s() failed: %s', __app.health_function, SQLERRM );
    END;
    IF __reason IS NOT NULL THEN
        RETURN format( 'its health function %s() reports: %s', __app.health_function, __reason );
    END IF;
    RETURN NULL;
EXCEPTION WHEN insufficient_privilege THEN
    -- A dependent's role need not have USAGE on the schema of the app it depends on, nor
    -- EXECUTE on its health function; unable to tell, it is treated as healthy.
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
    __installer_classid INTEGER := hashtext( 'hive_fork_manager_app_installer_lock' );
    __objid INTEGER := hashtext( _app_name );
    __holders TEXT;
    __reason TEXT;
    __unregistered BOOLEAN;
    __deadline TIMESTAMPTZ;
BEGIN
    __holders := hive._try_advisory_lock( __installer_classid, __objid, TRUE );
    IF __holders IS NOT NULL THEN
        RAISE NOTICE 'Skipping install: another installer of % is running: %', _app_name, __holders;
        RETURN FALSE;
    END IF;

    __holders := hive._try_app_lock( _app_name, TRUE );
    IF __holders IS NULL THEN
        RETURN TRUE;
    END IF;

    __unregistered := NOT EXISTS ( SELECT 1 FROM hafd.applications a WHERE a.name = _app_name );
    IF __unregistered THEN
        __reason := 'no application is registered under that name';
    ELSE
        __reason := hive._app_broken_reason( _app_name );
        IF __reason IS NULL THEN
            PERFORM pg_advisory_unlock( __installer_classid, __objid );
            RAISE NOTICE 'Skipping install: lock on % held by %', _app_name, __holders;
            RETURN FALSE;
        END IF;
    END IF;

    -- A block-processor starting up holds a broken app's lock only until it notices
    -- the breakage, so give such holders a moment to let go.
    RAISE NOTICE 'Waiting for lock on %: held by % while %', _app_name, __holders, __reason;
    __deadline := clock_timestamp() + interval '10 seconds';
    WHILE clock_timestamp() < __deadline LOOP
        PERFORM pg_sleep( 0.5 );
        __holders := hive._try_app_lock( _app_name, TRUE );
        IF __holders IS NULL THEN
            RETURN TRUE;
        END IF;
    END LOOP;

    -- Holders of an app that is not installed (dependents' block-processors, which keep
    -- their locks across the dependency's absence) cannot be doing useful work on it.
    IF __unregistered THEN
        RAISE NOTICE 'Installing % without its lock: % and it is still held by %', _app_name, __reason, __holders;
        RETURN TRUE;
    END IF;

    -- Advisory locks survive the error, hence the explicit release.
    PERFORM pg_advisory_unlock( __installer_classid, __objid );
    RAISE EXCEPTION 'Cannot install %: % and its lock is held by %; stop those sessions and rerun the install',
                    _app_name, __reason, __holders;
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
    __reason     TEXT;
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
        __reason := hive._app_broken_reason( __app );
        IF __reason IS NOT NULL THEN
            FOREACH __locked IN ARRAY _app_names LOOP
                PERFORM pg_advisory_unlock_shared( hashtext( 'hive_fork_manager_app_lock' ), hashtext( __locked ) );
            END LOOP;
            RAISE EXCEPTION 'Cannot take block-processor lock on %: %; reinstall the application', __app, __reason;
        END IF;
    END LOOP;
END;
$BODY$
;
