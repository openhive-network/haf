-- An application registered without a process procedure (hivemind's shape) whose
-- completed block function is gone: its installer does not skip on a held lock, and
-- a block-processor refuses to take the lock.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    CREATE FUNCTION A.completed_block_num() RETURNS INTEGER LANGUAGE sql AS $$ SELECT 0 $$;
    GRANT USAGE ON SCHEMA A TO alice;
    PERFORM hive.app_create_context( _name => 'self_driven_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_register( 'self_driven_app', ARRAY[ 'self_driven_ctx' ], NULL, 'a.completed_block_num' );
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
    PERFORM dblink_connect( 'holder', format( 'host=localhost port=%s dbname=%s user=alice password=test application_name=stuck_loop'
        , current_setting( 'port' ), current_database() ) );
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''self_driven_app'' ] )' ) AS t( r TEXT );
    DROP FUNCTION A.completed_block_num();

    -- the holder stays
    BEGIN
        __acquired := hive.try_acquire_app_install_lock( 'self_driven_app' );
        __error := format( 'returned %s', __acquired );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error LIKE 'Cannot install self_driven_app: its completed block function a.completed_block_num() does not exist and its lock is held by stuck_loop (pid=%'
        , format( 'the installer did not fail naming the function and the holder: %s', __error );

    -- the holder lets go while the installer waits
    PERFORM dblink_send_query( 'holder', 'SELECT pg_advisory_unlock_all() FROM pg_sleep( 2 )' );
    __acquired := hive.try_acquire_app_install_lock( 'self_driven_app' );
    ASSERT __acquired, 'the installer did not take the lock released by the holder';
    PERFORM * FROM dblink_get_result( 'holder' ) AS t( r TEXT );
    PERFORM dblink_disconnect( 'holder' );
    PERFORM pg_advisory_unlock_all();

    __error := NULL;
    BEGIN
        PERFORM hive.acquire_app_block_processor_locks( ARRAY[ 'self_driven_ctx_dependency', 'self_driven_app' ] );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Cannot take block-processor lock on self_driven_app: its completed block function a.completed_block_num() does not exist; reinstall the application'
        , format( 'the block-processor did not refuse the lock: %s', __error );
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks WHERE pid = pg_backend_pid() AND locktype = 'advisory' ), 'the refused block-processor kept an advisory lock';
END;
$BODY$
;
