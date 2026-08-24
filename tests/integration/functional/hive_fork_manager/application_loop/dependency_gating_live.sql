-- Application registry (issue #341): live-stage (forking, event driven) flavour of
-- dependency gating. Both contexts are forking and in the live stage. A reversible
-- block is pushed; 'child' (depends on 'parent') must not consume its NEW_BLOCK
-- event until parent has processed that block, then must receive it.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'parent', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'child', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_register( 'parent_app', ARRAY[ 'parent' ] );
    PERFORM hive.app_register( 'child_app', ARRAY[ 'child' ] );
    PERFORM hive.app_add_dependency( 'child_app', 'parent_app' );
    CREATE TABLE A.child_ranges( step TEXT, first_block INTEGER, last_block INTEGER );

    FOR __block IN 1 .. 3 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL
            , CASE WHEN __block = 1 THEN ARRAY[ ( 5, 'initminer', 1 )::hafd.accounts ] ELSE NULL END
            , NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 3 );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 3 );
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
BEGIN
    -- bring both to the head (3), parent first
    FOR __i IN 1 .. 10 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'parent' ], __blocks, _wait => FALSE );
        EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 3;
    END LOOP;
    FOR __i IN 1 .. 10 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        IF __blocks IS NOT NULL THEN
            INSERT INTO A.child_ranges VALUES ( 'catch_up', __blocks.first_block, __blocks.last_block );
        END IF;
        EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 3;
    END LOOP;
    ASSERT hive.get_current_stage_name( 'child' ) = 'live', 'child is not live';
    ASSERT hive.app_context_is_attached( 'child' ), 'child is not attached';

    -- a new reversible block arrives (NEW_BLOCK event for both contexts)
    PERFORM hive.push_block(
         ( 4, '\xBADD04', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM test.set_head_block_num( 4 );

    -- child first: parent is still at 3, so block 4 must be withheld
    FOR __i IN 1 .. 3 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        IF __blocks IS NOT NULL THEN
            INSERT INTO A.child_ranges VALUES ( 'gated', __blocks.first_block, __blocks.last_block );
        END IF;
    END LOOP;

    -- parent processes block 4
    FOR __i IN 1 .. 5 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'parent' ], __blocks, _wait => FALSE );
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 4;
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 4, 'parent did not process block 4';

    -- now child gets it
    FOR __i IN 1 .. 5 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        IF __blocks IS NOT NULL THEN
            INSERT INTO A.child_ranges VALUES ( 'released', __blocks.first_block, __blocks.last_block );
        END IF;
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 4;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT 1 FROM A.child_ranges WHERE step = 'gated' ), 'child received block 4 before parent processed it';
    ASSERT ( SELECT COUNT(*) FROM A.child_ranges WHERE step = 'released' AND first_block = 4 AND last_block = 4 ) = 1, 'child did not receive block 4 after parent processed it';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 4, 'child did not reach block 4';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 4, 'parent did not stay at block 4';
END;
$BODY$
;
