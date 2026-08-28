-- Application registry (issue #341): a dependency registered with a
-- completed_block_function is gated by that function's result, not by its
-- contexts' current_block_num (for loops that commit the position ahead of the
-- data, e.g. hivemind's massive sync). Here 'parent' reports a completed block
-- that trails its position by 2 through a.parent_completed().

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
    CREATE TABLE A.lag( blocks INTEGER );
    INSERT INTO A.lag VALUES ( 2 );

    CREATE FUNCTION A.parent_completed() RETURNS INTEGER LANGUAGE sql STABLE AS
        $f$ SELECT GREATEST( 0, ( SELECT current_block_num FROM hafd.contexts WHERE name = 'parent' ) - ( SELECT blocks FROM A.lag ) ) $f$;

    PERFORM hive.app_register( 'parent_app', ARRAY[ 'parent' ], NULL, 'a.parent_completed' );
    PERFORM hive.app_register( 'child_app', ARRAY[ 'child' ] );
    PERFORM hive.app_add_dependency( 'child_app', 'parent_app' );

    CREATE TABLE A.delivered( parent_position INTEGER, parent_completed INTEGER, first_block INTEGER, last_block INTEGER );

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
    ASSERT hive.app_dependencies_block_limit( ARRAY[ 'child' ] ) = 0, 'limit must be 0 before parent starts';

    FOR __i IN 1 .. 40 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'parent' ], __blocks, _wait => FALSE );
        SELECT current_block_num INTO __parent FROM hafd.contexts WHERE name = 'parent';
        ASSERT hive.app_dependencies_block_limit( ARRAY[ 'child' ] ) = A.parent_completed(), 'limit must follow the completed-block function';

        LOOP
            CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
            EXIT WHEN __blocks IS NULL;
            INSERT INTO A.delivered VALUES ( __parent, A.parent_completed(), __blocks.first_block, __blocks.last_block );
        END LOOP;

        EXIT WHEN __parent >= 20;
    END LOOP;

    -- parent's data is now complete: report it and let child finish
    UPDATE A.lag SET blocks = 0;
    LOOP
        CALL hive.app_next_iteration( ARRAY[ 'child' ], __blocks, _wait => FALSE );
        EXIT WHEN __blocks IS NULL;
        INSERT INTO A.delivered VALUES ( __parent, A.parent_completed(), __blocks.first_block, __blocks.last_block );
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
BEGIN
    SELECT COUNT(*) INTO __violations FROM A.delivered WHERE last_block > parent_completed;
    ASSERT __violations = 0, FORMAT( '%s range(s) were delivered beyond the parent''s completed block', __violations );
    ASSERT EXISTS ( SELECT 1 FROM A.delivered WHERE last_block < parent_position ), 'child was never held back behind parent''s position (the lag never mattered)';

    SELECT COUNT(*) INTO __missing
    FROM generate_series( 1, 20 ) AS b( num )
    WHERE NOT EXISTS ( SELECT 1 FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block );
    ASSERT __missing = 0, FORMAT( '%s block(s) were never delivered to child', __missing );
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'child' ) = 20, 'child did not reach the head';
END;
$BODY$
;
