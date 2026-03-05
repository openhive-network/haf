-- Test remove_orphan_forks function with unified table architecture
-- Tests cleanup of orphan fork data when blocks become irreversible
-- Scenario: One context working on fork 2 at block 8
-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    -- Insert blocks into unified table using block_id encoding
    -- Fork 1: blocks 4, 5, 6, 7, 10
    -- Fork 2: blocks 7, 8, 9
    -- Fork 3: blocks 8, 9, 10
    INSERT INTO hafd.blocks(block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
    VALUES
           ( hafd.make_block_id(4, 1), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(5, 1), '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(6, 1), '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(7, 1), '\xBADD71', '\xCAFE71', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(10, 1), '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(7, 2), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 2), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 2), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 3), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 3), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    -- Insert accounts with block_id
    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES
           ( 1, 'u4_1', hafd.make_block_id(4, 1) )
         , ( 2, 'u5_1', hafd.make_block_id(5, 1) )
         , ( 3, 'u6_1', hafd.make_block_id(6, 1) )
         , ( 4, 'u7_1', hafd.make_block_id(7, 1) )
         , ( 5, 'u10_1', hafd.make_block_id(10, 1) )
         , ( 6, 'u7_2', hafd.make_block_id(7, 2) )
         , ( 7, 'u8_2', hafd.make_block_id(8, 2) )
         , ( 8, 'u9_2', hafd.make_block_id(9, 2) )
         , ( 9, 'u8_3', hafd.make_block_id(8, 3) )
         , ( 10, 'u9_3', hafd.make_block_id(9, 3) )
         , ( 11, 'u10_3', hafd.make_block_id(10, 3) )
    ;

    -- Insert transactions with block_id
    INSERT INTO hafd.transactions(block_id, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature)
    VALUES
           ( hafd.make_block_id(4, 1), 0::SMALLINT, '\xDEED40'::bytea, 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(5, 1), 0::SMALLINT, '\xDEED55'::bytea, 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(6, 1), 0::SMALLINT, '\xDEED60'::bytea, 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(7, 1), 0::SMALLINT, '\xDEED71'::bytea, 101, 100, '2016-06-22 19:10:37-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(10, 1), 0::SMALLINT, '\xDEED11'::bytea, 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(7, 2), 0::SMALLINT, '\xDEED72'::bytea, 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(8, 2), 0::SMALLINT, '\xDEED82'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(9, 2), 0::SMALLINT, '\xDEED92'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(8, 3), 0::SMALLINT, '\xDEED83'::bytea, 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(9, 3), 0::SMALLINT, '\xDEED93'::bytea, 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF'::bytea )
         , ( hafd.make_block_id(10, 3), 0::SMALLINT, '\xDEED0A03'::bytea, 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF'::bytea )
    ;

    -- Insert transactions_multisig with block_id
    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
           ( '\xDEED40'::bytea, '\xBEEF40'::bytea, hafd.make_block_id(4, 1) )
         , ( '\xDEED55'::bytea, '\xBEEF55'::bytea, hafd.make_block_id(5, 1) )
         , ( '\xDEED60'::bytea, '\xBEEF61'::bytea, hafd.make_block_id(6, 1) )
         , ( '\xDEED71'::bytea, '\xBEEF71'::bytea, hafd.make_block_id(7, 1) )
         , ( '\xDEED11'::bytea, '\xBEEF11'::bytea, hafd.make_block_id(10, 1) )
         , ( '\xDEED72'::bytea, '\xBEEF72'::bytea, hafd.make_block_id(7, 2) )
         , ( '\xDEED82'::bytea, '\xBEEF82'::bytea, hafd.make_block_id(8, 2) )
         , ( '\xDEED92'::bytea, '\xBEEF92'::bytea, hafd.make_block_id(9, 2) )
         , ( '\xDEED83'::bytea, '\xBEEF83'::bytea, hafd.make_block_id(8, 3) )
         , ( '\xDEED93'::bytea, '\xBEEF93'::bytea, hafd.make_block_id(9, 3) )
         , ( '\xDEED0A03'::bytea, '\xBEEF0A03'::bytea, hafd.make_block_id(10, 3) )
    ;

    -- Insert operations with block_id
    INSERT INTO hafd.operations(block_id, trx_in_block, op_type_id, op_pos, body_binary, id)
    VALUES
           ( hafd.make_block_id(4, 1), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"FOUR OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(4,1) )
         , ( hafd.make_block_id(5, 1), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(5,1) )
         , ( hafd.make_block_id(6, 1), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(6,1) )
         , ( hafd.make_block_id(7, 1), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN1 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7,1) )
         , ( hafd.make_block_id(7, 2), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7,2) )
         , ( hafd.make_block_id(8, 2), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(8,1) )
         , ( hafd.make_block_id(9, 2), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(9,1) )
         , ( hafd.make_block_id(8, 3), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(8,2) )
         , ( hafd.make_block_id(9, 3), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(9,2) )
         , ( hafd.make_block_id(10, 3), 0, 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN3 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(10,1) )
    ;

    -- Insert account_operations with block_id
    INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, block_id, operation_id, op_type_id)
    VALUES
           ( 1, 1, 1, hafd.make_block_id(4, 1), hafd.operation_id(4, 1), 0 )
         , ( 2, 2, 1, hafd.make_block_id(5, 1), hafd.operation_id(5, 1), 0 )
         , ( 3, 3, 1, hafd.make_block_id(6, 1), hafd.operation_id(6, 1), 0 )
         , ( 4, 4, 1, hafd.make_block_id(7, 1), hafd.operation_id(7, 1), 0 )
         , ( 6, 6, 1, hafd.make_block_id(7, 2), hafd.operation_id(7, 1), 0 )
         , ( 7, 7, 1, hafd.make_block_id(8, 2), hafd.operation_id(8, 1), 0 )
         , ( 8, 8, 1, hafd.make_block_id(9, 2), hafd.operation_id(9, 1), 0 )
         , ( 9, 9, 1, hafd.make_block_id(8, 3), hafd.operation_id(8, 1), 0 )
         , ( 10, 10, 1, hafd.make_block_id(9, 3), hafd.operation_id(9, 2), 0 )
         , ( 11, 11, 1, hafd.make_block_id(10, 3), hafd.operation_id(10, 1), 0 )
    ;

    -- Insert applied_hardforks with block_id
    INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
    VALUES
           ( 4, hafd.make_block_id(4, 1), hafd.operation_id(4,1) )
         , ( 5, hafd.make_block_id(5, 1), hafd.operation_id(5,1) )
         , ( 6, hafd.make_block_id(6, 1), hafd.operation_id(6,1) )
         , ( 7, hafd.make_block_id(7, 2), hafd.operation_id(7,2) )
         , ( 8, hafd.make_block_id(8, 3), hafd.operation_id(8,2) )
         , ( 9, hafd.make_block_id(9, 3), hafd.operation_id(9,2) )
         , ( 10, hafd.make_block_id(10, 3), hafd.operation_id(10,1) )
    ;

    -- Context working on fork 2 at block 8
    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 8, current_block_num = 8;

    -- SUMMARY:
    -- We have 3 forks: 1 (blocks: 4,5,6,7,10), 2 (blocks: 7,8,9), 3 (blocks: 8,9,10)
    -- Context is working on block 8 on fork 2

    -- Record block conflicts for block_nums that have multiple fork versions
    -- (normally populated by push_block(), but we insert data directly in tests)
    INSERT INTO hafd.block_conflicts (block_num) VALUES (7), (8), (9), (10);

    -- Set state to LIVE to simulate live sync where forks can happen
    -- (remove_orphan_forks only executes during LIVE state)
    UPDATE hafd.hive_state SET state = 'LIVE';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- block 8 from current top fork (nr 3) becomes irreversible
    -- This should remove orphan forks (fork 1 blocks <= 8 where higher fork exists)
    PERFORM hive.remove_orphan_forks( 8 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- After remove_orphan_forks(8):
    -- For blocks 4,5,6,7,8: keep highest fork_id, remove lower forks
    -- Fork 1 blocks 4,5,6,7 should be removed (orphaned by forks 2,3)
    -- Fork 2 block 7 should be removed (orphaned by fork 3 for block 8+)
    -- BUT we keep fork 2 blocks 7,8,9 because context is working there
    -- Fork 3 blocks 8,9,10 should remain (highest fork)
    -- Fork 1 block 10 should remain (no higher fork at block 10... actually fork 3 has block 10)

    -- After orphan removal, blocks on lower forks at same block_num are removed
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks ) >= 6, 'Too few blocks remaining';

    -- Verify fork 3 blocks remain
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(8, 3)), 'Fork 3 block 8 missing';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(9, 3)), 'Fork 3 block 9 missing';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(10, 3)), 'Fork 3 block 10 missing';

    -- Fork 1 blocks <= 8 should be removed as orphans (higher fork exists)
    -- Block 4,5,6 on fork 1 have no higher fork, so they might remain
    -- Actually, remove_orphan_forks removes blocks where a HIGHER fork_id exists at same block_num
    -- Fork 1 block 7 should be removed (fork 2 has block 7)

    -- Verify orphan blocks are removed
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 should be removed (orphan)';

    -- Fork 2 block 8 should be removed (fork 3 has higher fork_id at block 8)
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(8, 2)), 'Fork 2 block 8 should be removed (orphan)';

    -- Verify associated data is cleaned up
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.accounts WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 accounts should be removed';
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.transactions WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 transactions should be removed';
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.operations WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 operations should be removed';

END;
$BODY$
;
