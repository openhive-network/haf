-- An application whose registration is gone (its last context was removed) is not
-- installed: a dependent's block-processor holding its lock cannot be doing useful
-- work on it, so its installer proceeds after waiting for the holder. Block-processors
-- still take the lock of an application that is not registered.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    CREATE PROCEDURE A.process_blocks( _blocks hive.blocks_range ) LANGUAGE plpgsql AS $$ BEGIN END $$;
    GRANT USAGE ON SCHEMA A TO alice;
    PERFORM hive.app_create_context( _name => 'gone_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_register( 'gone_app', ARRAY[ 'gone_ctx' ], 'a.process_blocks' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __acquired BOOLEAN;
    __started TIMESTAMPTZ;
BEGIN
    PERFORM dblink_connect( 'holder', format( 'host=localhost port=%s dbname=%s user=alice password=test application_name=dependent_loop'
        , current_setting( 'port' ), current_database() ) );
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''gone_app'' ] )' ) AS t( r TEXT );
    PERFORM hive.app_remove_context( 'gone_ctx' );
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = 'gone_app' ), 'removing the last context did not unregister the application';

    __started := clock_timestamp();
    __acquired := hive.try_acquire_app_install_lock( 'gone_app' );
    ASSERT __acquired, 'the installer skipped an application that is not registered';
    ASSERT clock_timestamp() - __started >= interval '9 seconds', 'the installer did not wait for the holder';
    ASSERT EXISTS ( SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid = l.pid WHERE a.application_name = 'dependent_loop' AND l.locktype = 'advisory' AND l.granted )
        , 'the holder lost its lock';

    -- a block-processor starting before the application it depends on is installed
    PERFORM hive.acquire_app_block_processor_locks( ARRAY[ 'gone_app', 'never_registered_app' ] );
    ASSERT ( SELECT COUNT(*) FROM pg_locks WHERE pid = pg_backend_pid() AND locktype = 'advisory' AND mode = 'ShareLock' ) = 2
        , 'a block-processor did not take the locks of applications that are not registered';

    PERFORM pg_advisory_unlock_all();
    PERFORM dblink_disconnect( 'holder' );
END;
$BODY$
;
