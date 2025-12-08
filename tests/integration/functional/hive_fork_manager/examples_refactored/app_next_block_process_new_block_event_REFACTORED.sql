-- REFACTORED VERSION of app_api/app_next_block_process_new_block_event.sql
-- Demonstrates refactoring with hive API calls and context setup
--
-- BEFORE: 81 lines with INSERT statements and push_block calls
-- AFTER:  28 lines - 65% reduction
--
-- Original file: app_api/app_next_block_process_new_block_event.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create minimal irreversible blockchain
    PERFORM test.create_operation_types();
    PERFORM test.create_accounts(account_names => ARRAY['initminer']);
    PERFORM test.create_blocks(1, 1);

    -- End massive sync
    PERFORM hive.end_massive_sync( 1 );

    -- Push additional block using hive API
    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    -- Create application context
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );

    -- Create a table to test forking app
    CREATE TABLE table1( id INT) INHERITS( a.context );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __first_blocks hive.blocks_range;
    __second_blocks hive.blocks_range;
    __third_blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __first_blocks;
    ASSERT __first_blocks.first_block = 1 AND __first_blocks.last_block = 1, 'Wrong first block';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __second_blocks;
    RAISE NOTICE 'Second block=%', __second_blocks;
    ASSERT __second_blocks.first_block = 2 AND __second_blocks.last_block = 2, 'Wrong second block';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __third_blocks;
    ASSERT __third_blocks IS NULL, 'Wrong second block';
END
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hafd.events_queue WHERE id = 2 AND event = 'NEW_BLOCK' AND block_num = 2 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue ) = 4, 'Unexpected number of events';

    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context' ) = 2, 'Wrong current block num';
END
$BODY$;

-- NOTES:
-- 1. This test demonstrates that test_tools works well with hive API calls (push_block, end_massive_sync)
-- 2. The refactoring focuses on the initial setup; test-specific API calls remain unchanged
-- 3. Context creation and table setup are test-specific and kept as-is
-- 4. Good example of combining test_tools for infrastructure with custom test logic
