-- Application registry (issue #341): an application never receives a block that one
-- of its dependencies has not processed yet. Massive-stage (non-forking) flavour:
-- 'child' depends on 'parent'; the loop is driven by hand so parent's position is
-- known at every child iteration. Every range delivered to child must end at or
-- before parent's position at that moment, and child must still reach the head
-- once parent does.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'parent', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 4 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'child', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_register( 'parent_app', ARRAY[ 'parent' ] );
    PERFORM hive.app_register( 'child_app', ARRAY[ 'child' ] );
    PERFORM hive.app_add_dependency( 'child_app', 'parent_app' );

    CREATE TABLE A.delivered( iteration INTEGER, parent_position INTEGER, first_block INTEGER, last_block INTEGER );

    FOR __block IN 1 .. 20 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL
            , CASE WHEN __block = 1 THEN ARRAY[ ( 5, 'initminer', 1 )::hafd.accounts ] ELSE NULL END
            , NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 20 );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 20 );
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
    __parent INTEGER;
BEGIN
    ASSERT hive.app_dependencies_block_limit( ARRAY[ 'child' ] ) = 0, 'limit must equal parent position (0) before parent starts';
    ASSERT hive.app_dependencies_block_limit( ARRAY[ 'parent' ] ) IS NULL, 'parent has no dependencies';

    -- child alone: parent is at 0, so nothing may be delivered
    FOR __i IN 1 .. 3 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        ASSERT __blocks IS NULL, 'child got ' || __blocks::TEXT || ' while parent was at 0';
    END LOOP;

    -- alternate: one parent iteration (batches of 4), then child iterations until it
    -- catches up with parent
    FOR __i IN 1 .. 40 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'parent' ], __blocks, _wait => FALSE );
        SELECT current_block_num INTO __parent FROM hafd.contexts WHERE name = 'parent';

        LOOP
            CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
            EXIT WHEN __blocks IS NULL;
            INSERT INTO A.delivered VALUES ( __i, __parent, __blocks.first_block, __blocks.last_block );
        END LOOP;

        EXIT WHEN __parent >= 20 AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) >= 20;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __violations INTEGER;
    __missing INTEGER;
    __duplicated INTEGER;
BEGIN
    SELECT COUNT(*) INTO __violations FROM A.delivered WHERE last_block > parent_position;
    ASSERT __violations = 0, FORMAT( '%s range(s) were delivered to child beyond parent''s position', __violations );

    SELECT COUNT(*) INTO __missing
    FROM generate_series( 1, 20 ) AS b( num )
    WHERE NOT EXISTS ( SELECT 1 FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block );
    ASSERT __missing = 0, FORMAT( '%s block(s) were never delivered to child', __missing );

    SELECT COUNT(*) INTO __duplicated
    FROM generate_series( 1, 20 ) AS b( num )
    WHERE ( SELECT COUNT(*) FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block ) > 1;
    ASSERT __duplicated = 0, FORMAT( '%s block(s) were delivered to child more than once', __duplicated );

    -- child's batch is 100 but it must have been chopped to parent's progress
    ASSERT ( SELECT COUNT(*) FROM A.delivered ) > 1, 'child was expected to need several gated ranges';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 20, 'child did not reach the head';
END;
$BODY$
;
