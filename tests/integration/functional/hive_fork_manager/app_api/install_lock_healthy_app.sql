-- An installer whose application is healthy skips its work while a block-processor
-- holds the application's shared lock.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    CREATE PROCEDURE A.process_blocks( _blocks hive.blocks_range ) LANGUAGE plpgsql AS $$ BEGIN END $$;
    GRANT USAGE ON SCHEMA A TO alice;
    PERFORM hive.app_create_context( _name => 'healthy_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_register( 'healthy_app', ARRAY[ 'healthy_ctx' ], 'a.process_blocks' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __acquired BOOLEAN;
BEGIN
    PERFORM dblink_connect( 'holder', format( 'host=localhost port=%s dbname=%s user=alice password=test application_name=healthy_loop'
        , current_setting( 'port' ), current_database() ) );
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''healthy_app'' ] )' ) AS t( r TEXT );

    __acquired := hive.try_acquire_app_install_lock( 'healthy_app' );
    ASSERT __acquired = FALSE, 'the installer took the lock of a healthy application held by its block-processor';
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks WHERE pid = pg_backend_pid() AND locktype = 'advisory' ), 'the skipping installer holds an advisory lock';

    PERFORM dblink_disconnect( 'holder' );
END;
$BODY$
;
