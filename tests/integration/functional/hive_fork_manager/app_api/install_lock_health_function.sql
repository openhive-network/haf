-- An application with a health function: while it returns NULL the locks behave as
-- for any healthy application; once it reports a reason or fails, the installer does
-- not skip on a held lock and a block-processor refuses the lock, quoting it.
-- The holder (alice) may read neither the state table nor anything else in A but
-- the SECURITY DEFINER health function.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    CREATE TABLE A.health_state( reason TEXT, fail BOOLEAN NOT NULL );
    INSERT INTO A.health_state VALUES ( NULL, FALSE );
    CREATE FUNCTION A.health() RETURNS TEXT LANGUAGE plpgsql STABLE SECURITY DEFINER AS
    $$
    DECLARE
        __state A.health_state;
    BEGIN
        SELECT * INTO __state FROM A.health_state;
        IF __state.fail THEN
            RAISE EXCEPTION 'health state unreadable';
        END IF;
        RETURN __state.reason;
    END
    $$;
    GRANT USAGE ON SCHEMA A TO alice;
    PERFORM hive.app_create_context( _name => 'checked_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_register( 'checked_app', ARRAY[ 'checked_ctx' ], _health_function => 'a.health' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __acquired BOOLEAN;
    __error TEXT;
BEGIN
    -- healthy: the block-processor keeps the lock and the installer skips
    PERFORM dblink_connect( 'holder', format( 'host=localhost port=%s dbname=%s user=alice password=test application_name=checked_loop'
        , current_setting( 'port' ), current_database() ) );
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''checked_app'' ] )' ) AS t( r TEXT );
    __acquired := hive.try_acquire_app_install_lock( 'checked_app' );
    ASSERT __acquired = FALSE, 'the installer took the lock of a healthy application held by its block-processor';
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks WHERE pid = pg_backend_pid() AND locktype = 'advisory' ), 'the skipping installer holds an advisory lock';

    -- reports a reason while the holder stays
    UPDATE A.health_state SET reason = 'index missing';
    COMMIT; -- visible to the holder
    BEGIN
        __acquired := hive.try_acquire_app_install_lock( 'checked_app' );
        __error := format( 'returned %s', __acquired );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error LIKE 'Cannot install checked_app: its health function a.health() reports: index missing and its lock is held by checked_loop (pid=%'
        , format( 'the installer did not fail quoting the reason and naming the holder: %s', __error );

    -- the holder lets go while the installer waits
    PERFORM dblink_send_query( 'holder', 'SELECT pg_advisory_unlock_all() FROM pg_sleep( 2 )' );
    __acquired := hive.try_acquire_app_install_lock( 'checked_app' );
    ASSERT __acquired, 'the installer did not take the lock released by the holder';
    PERFORM * FROM dblink_get_result( 'holder' ) AS t( r TEXT );
    PERFORM * FROM dblink_get_result( 'holder' ) AS t( r TEXT ); -- the end of the async query, so the connection takes another
    PERFORM pg_advisory_unlock_all();

    -- a block-processor, running the health function under alice's role
    __error := NULL;
    BEGIN
        PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''checked_dependency'', ''checked_app'' ] )' ) AS t( r TEXT );
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error LIKE '%Cannot take block-processor lock on checked_app: its health function a.health() reports: index missing; reinstall the application%'
        , format( 'the block-processor did not refuse the lock quoting the reason: %s', __error );
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid = l.pid WHERE a.application_name = 'checked_loop' AND l.locktype = 'advisory' )
        , 'the refused block-processor kept an advisory lock';

    -- fails
    UPDATE A.health_state SET reason = NULL, fail = TRUE;
    COMMIT; -- visible to the holder
    __error := NULL;
    BEGIN
        PERFORM hive.acquire_app_block_processor_locks( ARRAY[ 'checked_app' ] );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Cannot take block-processor lock on checked_app: its health function a.health() failed: health state unreadable; reinstall the application'
        , format( 'the block-processor did not refuse the lock of an application whose health function fails: %s', __error );
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks WHERE pid = pg_backend_pid() AND locktype = 'advisory' ), 'the refused block-processor kept an advisory lock';

    -- healthy again
    UPDATE A.health_state SET fail = FALSE;
    COMMIT; -- visible to the holder
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''checked_app'' ] )' ) AS t( r TEXT );
    ASSERT hive.try_acquire_app_install_lock( 'checked_app' ) = FALSE, 'the installer took the lock of a recovered application held by its block-processor';
    PERFORM dblink_disconnect( 'holder' );
END;
$BODY$
;
