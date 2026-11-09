-- Two installers of an application that is not registered, while a dependent's
-- block-processor holds its lock: the installer proceeding without the lock keeps
-- the other out until it ends, also once the holder has gone.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
END;
$BODY$
;

-- dblink_disconnect returns before the server ends the session and releases its locks
CREATE OR REPLACE PROCEDURE public.wait_for_session_end( _application_name TEXT )
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __deadline TIMESTAMPTZ := clock_timestamp() + interval '10 seconds';
BEGIN
    WHILE EXISTS ( SELECT 1 FROM pg_stat_activity WHERE application_name = _application_name ) LOOP
        ASSERT clock_timestamp() < __deadline, format( 'the session %s did not end', _application_name );
        PERFORM pg_sleep( 0.1 );
        PERFORM pg_stat_clear_snapshot();
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __installer TEXT;
    __proceeded TEXT[] := ARRAY[]::TEXT[];
    __skipped TEXT;
    __acquired BOOLEAN;
BEGIN
    FOREACH __installer IN ARRAY ARRAY[ 'holder', 'installer_a', 'installer_b' ] LOOP
        PERFORM dblink_connect( __installer, format( 'host=localhost port=%s dbname=%s user=alice password=test application_name=%s'
            , current_setting( 'port' ), current_database(), __installer ) );
    END LOOP;
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''unregistered_app'' ] )' ) AS t( r TEXT );

    PERFORM dblink_send_query( 'installer_a', 'SELECT hive.try_acquire_app_install_lock( ''unregistered_app'' )' );
    PERFORM dblink_send_query( 'installer_b', 'SELECT hive.try_acquire_app_install_lock( ''unregistered_app'' )' );
    FOREACH __installer IN ARRAY ARRAY[ 'installer_a', 'installer_b' ] LOOP
        SELECT r INTO __acquired FROM dblink_get_result( __installer ) AS t( r BOOLEAN );
        PERFORM * FROM dblink_get_result( __installer ) AS t( r BOOLEAN );
        IF __acquired THEN
            __proceeded := __proceeded || __installer;
        ELSE
            __skipped := __installer;
        END IF;
    END LOOP;
    ASSERT cardinality( __proceeded ) = 1, format( 'not exactly one installer proceeded: %s', __proceeded );
    ASSERT EXISTS ( SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid = l.pid WHERE a.application_name = 'holder' AND l.locktype = 'advisory' AND l.granted )
        , 'the holder lost its lock';

    -- the app lock is free now, the installer lock is still held
    PERFORM dblink_disconnect( 'holder' );
    CALL public.wait_for_session_end( 'holder' );
    SELECT r INTO __acquired FROM dblink( __skipped, 'SELECT hive.try_acquire_app_install_lock( ''unregistered_app'' )' ) AS t( r BOOLEAN );
    ASSERT __acquired = FALSE, 'a second installer proceeded while the first one still installs';
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid = l.pid WHERE a.application_name = __skipped AND l.locktype = 'advisory' AND l.granted )
        , 'the skipping installer holds an advisory lock';

    PERFORM dblink_disconnect( __proceeded[ 1 ] );
    CALL public.wait_for_session_end( __proceeded[ 1 ] );
    SELECT r INTO __acquired FROM dblink( __skipped, 'SELECT hive.try_acquire_app_install_lock( ''unregistered_app'' )' ) AS t( r BOOLEAN );
    ASSERT __acquired, 'the installer did not proceed once the first installer had ended';

    PERFORM dblink_disconnect( __skipped );
END;
$BODY$
;
