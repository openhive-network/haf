-- hive.app_next_iteration gets its blocks from the 3-argument hive.app_next_block,
-- so a setup that wraps it shapes the ranges an application is given. hivemind's CI
-- mocks (scripts/ci/wrapper_for_app_next_block.sql) rename it to
-- hive.app_next_block_haf and cap the ranges below the live tail of their sync;
-- the wrapper below caps them at block 4 the same way. When the loop bypassed
-- hive.app_next_block, the first batch ran past block 4.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'forking', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 3, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'nonforking', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 3, 100 ), hafd.live_stage() ] );
    CREATE TABLE A.ranges( name TEXT, iteration INTEGER, first_block INTEGER, last_block INTEGER );

    FOR __block IN 1 .. 10 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL
            , CASE WHEN __block = 1 THEN ARRAY[ ( 5, 'initminer', 1 )::hafd.accounts ] ELSE NULL END
            , NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 10 );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 10 );
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
    __ctx TEXT;
BEGIN
    -- installed here, not in given: the update test variant recreates hive.app_next_block between the steps
    ALTER FUNCTION hive.app_next_block( hive.contexts_group, BOOLEAN, INT ) RENAME TO app_next_block_haf;
    CREATE FUNCTION hive.app_next_block( _context_names hive.contexts_group, _wait BOOLEAN = TRUE, _block_limit INT = NULL )
        RETURNS hive.blocks_range
        LANGUAGE plpgsql
        VOLATILE
    AS
    $wrapper$
    DECLARE
        __result hive.blocks_range := hive.app_next_block_haf( _context_names, _wait, _block_limit );
    BEGIN
        IF __result IS NOT NULL
           AND hive.app_get_current_block_num( _context_names ) < 4
           AND __result.last_block > 4
        THEN
            __result.last_block := 4;
        END IF;
        RETURN __result;
    END;
    $wrapper$;

    FOREACH __ctx IN ARRAY ARRAY[ 'forking', 'nonforking' ] LOOP
        FOR __i IN 1 .. 10 LOOP
            CALL hive.app_next_iteration( ARRAY[ __ctx ], __blocks, _wait => FALSE );
            CONTINUE WHEN __blocks IS NULL;
            INSERT INTO A.ranges VALUES ( __ctx, __i, __blocks.first_block, __blocks.last_block );
        END LOOP;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __ctx TEXT;
    __ranges TEXT;
BEGIN
    FOREACH __ctx IN ARRAY ARRAY[ 'forking', 'nonforking' ] LOOP
        SELECT string_agg( format( '(%s,%s)', r.first_block, r.last_block ), ' ' ORDER BY r.iteration ) INTO __ranges
        FROM A.ranges r WHERE r.name = __ctx;

        ASSERT ( SELECT r.last_block FROM A.ranges r WHERE r.name = __ctx ORDER BY r.iteration LIMIT 1 ) = 4,
            FORMAT( '%s: the first range must end at the wrapper''s cap 4, got %s', __ctx, COALESCE( __ranges, 'none' ) );
        ASSERT ( SELECT MAX( r.last_block ) FROM A.ranges r WHERE r.name = __ctx ) = 10,
            FORMAT( '%s: the ranges after the cap must reach block 10, got %s', __ctx, __ranges );
        ASSERT NOT EXISTS (
            SELECT 1 FROM (
                SELECT r.first_block, LAG( r.last_block ) OVER ( ORDER BY r.iteration ) AS previous_last
                FROM A.ranges r WHERE r.name = __ctx
            ) s WHERE s.previous_last IS NOT NULL AND s.first_block != s.previous_last + 1
        ), FORMAT( '%s: the ranges must follow each other without a gap or an overlap, got %s', __ctx, __ranges );
    END LOOP;
END;
$BODY$
;
