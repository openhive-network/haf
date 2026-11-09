-- hive.app_set_health_function: records an existing function, refuses a missing one,
-- an unregistered application and a role that could not register the application;
-- NULL clears it, as does re-registering. alice owns alice_app; bob, who cannot
-- impersonate her, is refused, and alice_impersonal, who can, is let through.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE PROCEDURE A.process_blocks( _blocks hive.blocks_range ) LANGUAGE plpgsql AS $$ BEGIN END $$;
    CREATE FUNCTION A.completed_block_num() RETURNS INTEGER LANGUAGE sql AS $$ SELECT 0 $$;
    CREATE FUNCTION A.health() RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::TEXT $$;
    PERFORM hive.app_create_context( _name => 'ctx2', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_create_context( _name => 'ctx5', _schema => 'a', _is_forking => FALSE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice_app;
    CREATE FUNCTION alice_app.health() RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::TEXT $$;
    PERFORM hive.app_create_context( _name => 'alice_ctx', _schema => 'alice_app', _is_forking => FALSE );
    PERFORM hive.app_register( 'alice_app', ARRAY[ 'alice_ctx' ] );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __error TEXT;
BEGIN
    BEGIN
        PERFORM hive.app_set_health_function( 'app5', 'a.health' );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Application app5 is not registered', format( 'an unregistered application was not refused: %s', __error );

    PERFORM hive.app_register( 'app2', ARRAY[ 'ctx2' ] );
    PERFORM hive.app_register( 'app5', ARRAY[ 'ctx5' ], 'a.process_blocks', 'a.completed_block_num' );

    __error := NULL;
    BEGIN
        PERFORM hive.app_set_health_function( 'app5', 'x.missing' );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Cannot set the health function of application app5: function x.missing() does not exist', format( 'a missing health function was not refused: %s', __error );
    ASSERT ( SELECT health_function IS NULL FROM hafd.applications WHERE name = 'app5' ), 'the refused health function got recorded';

    PERFORM hive.app_set_health_function( 'app5', 'a.health' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_set_health_function( 'alice_app', 'alice_app.health' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __error TEXT;
BEGIN
    BEGIN
        PERFORM hive.app_set_health_function( 'alice_app', NULL );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Cannot set the health function of application alice_app: it is owned by alice, which role bob cannot impersonate'
        , format( 'a role that cannot register the application was not refused: %s', __error );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT array_agg( format( '%s|%s|%s|%s|%s', name, contexts, process_procedure, completed_block_function, health_function ) ORDER BY name ) FROM hafd.applications )
         = ARRAY[ 'alice_app|{alice_ctx}|||alice_app.health', 'app2|{ctx2}|||', 'app5|{ctx5}|a.process_blocks|a.completed_block_num|a.health' ]
        , 'the registrations differ from the calls';
    ASSERT hive._app_broken_reason( 'app5' ) IS NULL, 'an application whose health function reports nothing is reported broken';

    PERFORM hive.app_set_health_function( 'alice_app', NULL );
    ASSERT ( SELECT health_function IS NULL FROM hafd.applications WHERE name = 'alice_app' ), 'setting NULL kept the health function';

    -- re-registering clears it, as it does the other two when left out
    PERFORM hive.app_register( 'app5', ARRAY[ 'ctx5' ], 'a.process_blocks' );
    ASSERT ( SELECT health_function IS NULL FROM hafd.applications WHERE name = 'app5' ), 're-registering kept the health function';
END;
$BODY$
;
