-- An application whose registered process procedure is gone: its installer does not
-- skip on a held lock. It takes the lock once the holder lets go, or fails naming
-- the holder; a block-processor refuses to take the lock at all.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    CREATE PROCEDURE A.process_blocks( _blocks hive.blocks_range ) LANGUAGE plpgsql AS $$ BEGIN END $$;
    GRANT USAGE ON SCHEMA A TO alice;
    PERFORM hive.app_create_context( _name => 'broken_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_register( 'broken_app', ARRAY[ 'broken_ctx' ], 'a.process_blocks' );
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
    -- the block-processor took the lock before the procedure got dropped
    PERFORM dblink_connect( 'holder', format( 'host=localhost port=%s dbname=%s user=alice password=test application_name=stuck_loop'
        , current_setting( 'port' ), current_database() ) );
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''broken_app'' ] )' ) AS t( r TEXT );
    DROP PROCEDURE A.process_blocks( hive.blocks_range );

    -- the holder stays
    BEGIN
        __acquired := hive.try_acquire_app_install_lock( 'broken_app' );
        __error := format( 'returned %s', __acquired );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error LIKE 'Cannot install broken_app:%held by stuck_loop (pid=%', format( 'the installer did not fail naming the holder: %s', __error );

    -- the holder lets go while the installer waits
    PERFORM dblink_send_query( 'holder', 'SELECT pg_advisory_unlock_all() FROM pg_sleep( 2 )' );
    __acquired := hive.try_acquire_app_install_lock( 'broken_app' );
    ASSERT __acquired, 'the installer did not take the lock released by the holder';
    PERFORM * FROM dblink_get_result( 'holder' ) AS t( r TEXT );
    PERFORM dblink_disconnect( 'holder' );
    PERFORM pg_advisory_unlock_all();

    -- a block-processor of the broken application
    __error := NULL;
    BEGIN
        PERFORM hive.acquire_app_block_processor_locks( ARRAY[ 'broken_app' ] );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error LIKE 'Cannot take block-processor lock on broken_app:%a.process_blocks%', format( 'the block-processor did not refuse the lock: %s', __error );
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks WHERE pid = pg_backend_pid() AND locktype = 'advisory' ), 'the refused block-processor kept an advisory lock';
END;
$BODY$
;
