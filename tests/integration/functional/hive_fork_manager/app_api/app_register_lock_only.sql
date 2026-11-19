-- A lock-only application (no contexts, like HAfAH's API layer) is registered so that
-- the install-lock helpers treat its lock as a registered application's: a held
-- lock makes its installer skip instead of installing without the lock, and a
-- broken health function makes it wait and fail. Nothing may depend on it, and
-- hive.app_register still refuses an empty contexts group.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    CREATE TABLE A.health_state( reason TEXT );
    INSERT INTO A.health_state VALUES ( NULL );
    CREATE FUNCTION A.health() RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$ SELECT reason FROM A.health_state $$;
    GRANT USAGE ON SCHEMA A TO alice;
    PERFORM hive.app_create_context( _name => 'ctx_app_ctx', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_register( 'ctx_app', ARRAY[ 'ctx_app_ctx' ] );
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
    __error TEXT;
BEGIN
    PERFORM hive.app_register_lock_only( 'lock_app' );
    ASSERT ( SELECT format( '%s|%s|%s|%s|%s|%s', contexts, process_procedure, completed_block_function, health_function, paused, owner ) FROM hafd.applications WHERE name = 'lock_app' )
        = '{}||||f|haf_admin', 'wrong lock-only registration';

    PERFORM hive.app_pause( 'lock_app' );
    PERFORM hive.app_set_health_function( 'lock_app', 'a.health' );
    PERFORM hive.app_register_lock_only( 'lock_app' );
    ASSERT ( SELECT format( '%s|%s|%s', contexts, health_function, paused ) FROM hafd.applications WHERE name = 'lock_app' )
        = '{}||t', 're-registering did not keep paused and clear the health function';
    PERFORM hive.app_resume( 'lock_app' );
    ASSERT NOT ( SELECT paused FROM hafd.applications WHERE name = 'lock_app' ), 'the lock-only application was not resumed';
    ASSERT NOT hive.app_is_paused( ARRAY[ 'ctx_app_ctx' ] ), 'a lock-only application paused a context';

    BEGIN
        PERFORM hive.app_register_lock_only( 'ctx_app' );
        __error := 'no error';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Cannot register application ctx_app as lock-only: it is registered with contexts {ctx_app_ctx}'
        , format( 'a registration with contexts was made lock-only: %s', __error );
    ASSERT ( SELECT contexts FROM hafd.applications WHERE name = 'ctx_app' ) = ARRAY[ 'ctx_app_ctx' ], 'the refused call changed the registration';

    BEGIN
        PERFORM hive.app_register( 'empty_app', ARRAY[]::TEXT[] );
        __error := 'no error';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'value for domain hive.contexts_group violates check constraint "non_empty_contexts_group"', format( 'registering no contexts was not refused: %s', __error );
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = 'empty_app' ), 'an application without contexts got registered';

    BEGIN
        PERFORM hive.app_add_dependency( 'ctx_app', 'lock_app' );
        __error := 'no error';
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Application ctx_app cannot depend on lock_app: it is a lock-only application, which processes no blocks'
        , format( 'a dependency on a lock-only application was not refused: %s', __error );
    ASSERT hive.app_dependencies_block_limit( ARRAY[ 'ctx_app_ctx' ] ) IS NULL, 'the refused dependency gates ctx_app';

    -- healthy: an installer skips at once while the lock is held
    PERFORM hive.app_set_health_function( 'lock_app', 'a.health' );
    PERFORM dblink_connect( 'holder', format( 'host=localhost port=%s dbname=%s user=alice password=test application_name=lock_api'
        , current_setting( 'port' ), current_database() ) );
    PERFORM * FROM dblink( 'holder', 'SELECT hive.acquire_app_block_processor_locks( ARRAY[ ''lock_app'' ] )' ) AS t( r TEXT );
    __started := clock_timestamp();
    __acquired := hive.try_acquire_app_install_lock( 'lock_app' );
    ASSERT __acquired = FALSE, 'the installer of a lock-only application did not skip while its lock is held';
    ASSERT clock_timestamp() - __started < interval '5 seconds', 'the installer of a healthy lock-only application waited';

    -- broken: the installer waits for the holder, then fails naming it
    UPDATE A.health_state SET reason = 'api schema missing';
    COMMIT;
    BEGIN
        __acquired := hive.try_acquire_app_install_lock( 'lock_app' );
        __error := format( 'returned %s', __acquired );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error LIKE 'Cannot install lock_app: its health function a.health() reports: api schema missing and its lock is held by lock_api (pid=%'
        , format( 'the installer of a broken lock-only application did not fail naming the holder: %s', __error );
    PERFORM dblink_disconnect( 'holder' );

    PERFORM hive.app_unregister( 'lock_app' );
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = 'lock_app' ), 'the lock-only application was not unregistered';
END;
$BODY$
;
