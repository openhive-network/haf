-- A forking context that depends on another one goes live and processes a reversible
-- block. The next NEW_BLOCK is held back while its dependency lags; once the dependency
-- has processed further blocks, the context must still get every block in order, not
-- see a hole above the irreversible block ('current_block_num is reversible!').

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
    -- the update variant re-creates hive.get_estimated_hive_head_block() after 'given',
    -- which drops the mock
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 3 );

    FOR __i IN 1 .. 10 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'parent' ], __blocks, _wait => FALSE );
        EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 3;
    END LOOP;
    FOR __i IN 1 .. 10 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 3;
    END LOOP;
    ASSERT hive.get_current_stage_name( 'child' ) = 'live', 'child is not live';

    -- reversible block 4, processed by parent and then by child
    PERFORM hive.push_block(
         ( 4, '\xBADD04', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM test.set_head_block_num( 4 );
    FOR __i IN 1 .. 5 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'parent' ], __blocks, _wait => FALSE );
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 4;
    END LOOP;
    FOR __i IN 1 .. 5 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 4;
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 4, 'child did not process block 4';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'child' ) < 4, 'child is not in the reversible range';

    -- block 5 arrives, parent lags at 4: child must wait for it
    PERFORM hive.push_block(
         ( 5, '\xBADD05', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM test.set_head_block_num( 5 );
    FOR __i IN 1 .. 3 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        IF __blocks IS NOT NULL THEN
            INSERT INTO A.child_ranges VALUES ( 'gated', __blocks.first_block, __blocks.last_block );
        END IF;
    END LOOP;

    -- block 6 arrives and parent catches up to it, all still reversible
    PERFORM hive.push_block(
         ( 6, '\xBADD06', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM test.set_head_block_num( 6 );
    FOR __i IN 1 .. 5 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'parent' ], __blocks, _wait => FALSE );
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 6;
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) = 6, 'parent did not process block 6';
    ASSERT ( SELECT consistent_block FROM hafd.hive_state ) = 3, 'blocks 4..6 must stay reversible';

    FOR __i IN 1 .. 5 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        IF __blocks IS NOT NULL THEN
            INSERT INTO A.child_ranges VALUES ( 'released', __blocks.first_block, __blocks.last_block );
        END IF;
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 6;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT 1 FROM A.child_ranges WHERE step = 'gated' ), 'child received a block before parent processed it';
    ASSERT ( SELECT ARRAY_AGG( ( first_block, last_block )::hive.blocks_range ORDER BY first_block ) FROM A.child_ranges WHERE step = 'released' )
        = ARRAY[ ( 5, 5 )::hive.blocks_range, ( 6, 6 )::hive.blocks_range ], 'child did not receive blocks 5 and 6 one by one';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 6, 'child did not reach block 6';
END;
$BODY$
;
