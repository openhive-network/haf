-- Advisory-lock coordination between HAF app installers and block-processors.
--
-- Block-processors hold a SHARED advisory lock on each app they depend on
-- (including themselves) for the lifetime of their main-loop session.
-- Installers TRY an EXCLUSIVE advisory lock on the app they install; if any
-- shared holder exists, the installer skips its work and exits cleanly.
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


CREATE OR REPLACE FUNCTION hive.try_acquire_app_install_lock( _app_name TEXT )
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __holders TEXT;
BEGIN
    __holders := hive._try_app_lock( _app_name, TRUE );
    IF __holders IS NULL THEN
        RETURN TRUE;
    END IF;
    RAISE NOTICE 'Skipping install: lock on % held by %', _app_name, __holders;
    RETURN FALSE;
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
END;
$BODY$
;
