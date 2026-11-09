-- hive.app_register's _health_function: recorded when it exists, refused when it does
-- not; calls without it register as before.

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
    PERFORM hive.app_create_context( _name => 'ctx3', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_create_context( _name => 'ctx4', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_create_context( _name => 'ctx5', _schema => 'a', _is_forking => FALSE );
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
        PERFORM hive.app_register( 'app5', ARRAY[ 'ctx5' ], NULL, NULL, 'x.missing' );
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS __error = MESSAGE_TEXT;
    END;
    ASSERT __error = 'Cannot register application app5: function x.missing() does not exist', format( 'a missing health function was not refused: %s', __error );
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = 'app5' ), 'the refused application got registered';

    PERFORM hive.app_register( 'app2', ARRAY[ 'ctx2' ] );
    PERFORM hive.app_register( 'app3', ARRAY[ 'ctx3' ], 'a.process_blocks' );
    PERFORM hive.app_register( 'app4', ARRAY[ 'ctx4' ], NULL, 'a.completed_block_num' );
    PERFORM hive.app_register( 'app5', ARRAY[ 'ctx5' ], 'a.process_blocks', 'a.completed_block_num', 'a.health' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT array_agg( format( '%s|%s|%s|%s|%s', name, contexts, process_procedure, completed_block_function, health_function ) ORDER BY name ) FROM hafd.applications )
         = ARRAY[ 'app2|{ctx2}|||', 'app3|{ctx3}|a.process_blocks||', 'app4|{ctx4}||a.completed_block_num|', 'app5|{ctx5}|a.process_blocks|a.completed_block_num|a.health' ]
        , 'the registrations differ from the calls';

    -- re-registering without it clears it, as for the other two
    PERFORM hive.app_register( 'app5', ARRAY[ 'ctx5' ], 'a.process_blocks' );
    ASSERT ( SELECT health_function IS NULL FROM hafd.applications WHERE name = 'app5' ), 're-registering kept the health function';
    ASSERT hive._app_broken_reason( 'app4' ) IS NULL, 'a healthy application is reported broken';
END;
$BODY$
;
