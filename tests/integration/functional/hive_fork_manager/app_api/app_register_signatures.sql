-- Applications detect the registry with to_regprocedure on hive.app_register's
-- 4-argument signature. It resolves, and every call shape they use, positional or
-- named, resolves to one function; all five arguments register a health function.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE PROCEDURE A.process_blocks( _blocks hive.blocks_range ) LANGUAGE plpgsql AS $$ BEGIN END $$;
    CREATE FUNCTION A.completed_block_num() RETURNS INTEGER LANGUAGE sql AS $$ SELECT 0 $$;
    CREATE FUNCTION A.health() RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$ SELECT NULL::TEXT $$;
    PERFORM hive.app_create_context( _name => format( 'ctx%s', n ), _schema => 'a', _is_forking => FALSE ) FROM generate_series( 1, 8 ) AS n;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_register( 'app1', ARRAY[ 'ctx1' ] );
    PERFORM hive.app_register( 'app2', ARRAY[ 'ctx2' ], 'a.process_blocks' );
    PERFORM hive.app_register( 'app3', ARRAY[ 'ctx3' ], 'a.process_blocks', 'a.completed_block_num' );
    PERFORM hive.app_register( 'app4', ARRAY[ 'ctx4' ], _process_procedure => 'a.process_blocks' );
    PERFORM hive.app_register( 'app5', ARRAY[ 'ctx5' ], _completed_block_function => 'a.completed_block_num' );
    PERFORM hive.app_register( _name => 'app6', _contexts => ARRAY[ 'ctx6' ] );
    PERFORM hive.app_register( 'app7', ARRAY[ 'ctx7' ], NULL, NULL, 'a.health' );
    PERFORM hive.app_register( 'app8', ARRAY[ 'ctx8' ], _process_procedure => NULL, _completed_block_function => 'a.completed_block_num', _health_function => 'a.health' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT to_regprocedure( 'hive.app_register(text,hive.contexts_group,text,text)' ) IS NOT NULL, 'the 4-argument hive.app_register does not resolve';
    ASSERT to_regprocedure( 'hive.app_register(text,hive.contexts_group,text,text,text)' ) IS NOT NULL, 'the 5-argument hive.app_register does not resolve';

    ASSERT ( SELECT array_agg( format( '%s|%s|%s|%s|%s', name, contexts, process_procedure, completed_block_function, health_function ) ORDER BY name ) FROM hafd.applications )
         = ARRAY[ 'app1|{ctx1}|||', 'app2|{ctx2}|a.process_blocks||', 'app3|{ctx3}|a.process_blocks|a.completed_block_num|'
                , 'app4|{ctx4}|a.process_blocks||', 'app5|{ctx5}||a.completed_block_num|', 'app6|{ctx6}|||'
                , 'app7|{ctx7}|||a.health', 'app8|{ctx8}||a.completed_block_num|a.health' ]
        , 'the registrations differ from the calls';

    -- the 4-argument form re-registers like the 5-argument one with no health function
    PERFORM hive.app_register( 'app7', ARRAY[ 'ctx7' ], 'a.process_blocks', NULL );
    ASSERT ( SELECT format( '%s|%s', process_procedure, health_function ) FROM hafd.applications WHERE name = 'app7' ) = 'a.process_blocks|'
        , 'a 4-argument re-register did not clear the health function';
END;
$BODY$
;
