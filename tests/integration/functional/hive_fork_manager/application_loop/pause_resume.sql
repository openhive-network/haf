-- Application registry (issue #341): a paused application gets no block ranges from
-- hive.app_next_iteration; resuming it delivers them again. Also checks registry
-- bookkeeping: re-registration keeps the paused flag, dependency cycles are
-- rejected, removing a context unregisters an application that has no others.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'ctx', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 3 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'other', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 3 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'third', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 3 ), hafd.live_stage() ] );
    PERFORM hive.app_register( 'app', ARRAY[ 'ctx' ] );
    PERFORM hive.app_register( 'other_app', ARRAY[ 'other' ] );
    PERFORM hive.app_register( 'third_app', ARRAY[ 'third' ] );

    FOR __block IN 1 .. 12 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL
            , CASE WHEN __block = 1 THEN ARRAY[ ( 5, 'initminer', 1 )::hafd.accounts ] ELSE NULL END
            , NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 12 );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 12 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __i INTEGER;
    __cycle_rejected BOOLEAN := FALSE;
BEGIN
    CALL hive.app_next_iteration( ARRAY[ 'ctx' ], __blocks, _wait => FALSE );
    ASSERT __blocks = ( 1, 3 )::hive.blocks_range, 'first range expected (1,3), got ' || COALESCE( __blocks::TEXT, 'NULL' );

    PERFORM hive.app_pause( 'app' );
    ASSERT hive.app_is_paused( ARRAY[ 'ctx' ] ), 'app is not reported paused';
    FOR __i IN 1 .. 3 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'ctx' ], __blocks, _wait => FALSE );
        ASSERT __blocks IS NULL, 'paused app got ' || __blocks::TEXT;
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'ctx' ) = 3, 'paused app moved';

    -- re-registering (install scripts are re-run) keeps the paused flag
    PERFORM hive.app_register( 'app', ARRAY[ 'ctx' ] );
    ASSERT hive.app_is_paused( ARRAY[ 'ctx' ] ), 're-registration cleared the paused flag';

    PERFORM hive.app_resume( 'app' );
    CALL hive.app_next_iteration( ARRAY[ 'ctx' ], __blocks, _wait => FALSE );
    ASSERT __blocks = ( 4, 6 )::hive.blocks_range, 'range after resume expected (4,6), got ' || COALESCE( __blocks::TEXT, 'NULL' );

    -- dependency DAG: app -> other_app -> third_app
    PERFORM hive.app_add_dependency( 'app', 'other_app' );
    PERFORM hive.app_add_dependency( 'other_app', 'third_app' );
    ASSERT hive.app_dependencies_block_limit( ARRAY[ 'ctx' ] ) = 0, 'app must now be gated by other_app (at 0)';
    CALL hive.app_next_iteration( ARRAY[ 'ctx' ], __blocks, _wait => FALSE );
    ASSERT __blocks IS NULL, 'gated app got ' || COALESCE( __blocks::TEXT, 'NULL' );

    PERFORM hive.app_remove_dependency( 'app', 'other_app' );
    ASSERT hive.app_dependencies_block_limit( ARRAY[ 'ctx' ] ) IS NULL, 'dependency was not removed';

    -- closing the chain third_app -> app -> other_app -> third_app must be rejected
    -- (kept last: no transaction control may follow an EXCEPTION block)
    PERFORM hive.app_add_dependency( 'app', 'other_app' );
    BEGIN
        PERFORM hive.app_add_dependency( 'third_app', 'app' );
    EXCEPTION WHEN OTHERS THEN
        __cycle_rejected := TRUE;
    END;
    ASSERT __cycle_rejected, 'dependency cycle was accepted';

    -- removing an application's only context unregisters it and its dependencies
    PERFORM hive.app_remove_context( 'other' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = 'other_app' ), 'other_app survived removal of its only context';
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.application_dependencies WHERE application = 'other_app' OR depends_on = 'other_app' ), 'dependencies of other_app survived';
    ASSERT ( SELECT COUNT(*) FROM hafd.applications ) = 2, 'expected app and third_app to remain registered';
    ASSERT ( SELECT owner FROM hafd.applications WHERE name = 'app' ) = 'haf_admin', 'wrong owner recorded';
END;
$BODY$
;
