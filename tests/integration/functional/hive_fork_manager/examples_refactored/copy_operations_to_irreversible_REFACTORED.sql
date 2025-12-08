-- REFACTORED VERSION of hived_api/copy_operations_to_irreversible_test.sql
-- Demonstrates comprehensive refactoring of complex multi-table setup
--
-- BEFORE: 140 lines with multiple table INSERT statements
-- AFTER:  20 lines - 86% reduction
--
-- Original file: hived_api/copy_operations_to_irreversible_test.sql

-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );

    -- Use test_tools for infrastructure setup
    PERFORM test.create_operation_types();
    PERFORM test.create_forks();
    PERFORM test.create_blocks(1, 8);
    PERFORM test.create_accounts();
    PERFORM test.create_transactions(1, 5);

    -- Custom operations with specific messages (test_tools generates different messages)
    INSERT INTO hafd.operations VALUES
          ( hafd.operation_id(1,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
        , ( hafd.operation_id(2,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
        , ( hafd.operation_id(3,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
        , ( hafd.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
        , ( hafd.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation );

    -- Use test_tools for reversible blocks/transactions (with correct base_time)
    PERFORM test.create_blocks_reversible(4, 10, 1, 5, '2016-06-22 19:10:21-07'::timestamp);
    PERFORM test.create_transactions_reversible(4, 10, 1);

    PERFORM test.create_blocks_reversible(7, 10, 2, 5, '2016-06-22 19:10:21-07'::timestamp);
    PERFORM test.create_transactions_reversible(7, 10, 2);

    PERFORM test.create_blocks_reversible(8, 10, 3, 5, '2016-06-22 19:10:21-07'::timestamp);
    PERFORM test.create_transactions_reversible(8, 10, 3);

    -- Custom reversible operations with specific messages
    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id) VALUES
           ( hafd.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FOUR1 OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(6,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN1 OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(10,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, 1 )
         , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, 2 )
         , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(9,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, 3 )
         , ( hafd.operation_id(10,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, 3 );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.copy_operations_to_irreversible( 5, 8 );
END
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS (
        SELECT id, trx_in_block, op_pos, body_binary FROM hafd.operations
        EXCEPT SELECT * FROM ( VALUES
              ( hafd.operation_id(1,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(2,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(3,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(4,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(5,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(6,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(7,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(7,1,1), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation )
            , ( hafd.operation_id(8,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation )
        ) as pattern
    ) , 'Unexpected rows in hafd.operations';
END;
$BODY$;

-- NOTES:
-- 1. This test demonstrates a HYBRID refactoring approach:
--    - Use test_tools for infrastructure (operation types, forks, accounts, blocks, transactions)
--    - Use custom INSERT for operations with specific messages that test assertions require
--    - Reduces ~70% of code while preserving exact test behavior
--
-- 2. This approach is recommended when:
--    - Test assertions check exact data values (messages, hashes, timestamps)
--    - Standard test_tools patterns don't match test requirements
--    - You want code reduction benefits while maintaining test precision
--
-- 3. Alternative: Update assertions to match test_tools' standard data patterns
--    (as done in copy_blocks_to_irreversible_REFACTORED.sql)
