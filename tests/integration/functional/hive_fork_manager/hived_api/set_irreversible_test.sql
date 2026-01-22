DROP EXTENSION IF EXISTS hive_fork_manager CASCADE;
CREATE EXTENSION hive_fork_manager;
DO $$
BEGIN
    RAISE WARNING 'Initial Hive State Count: %', (SELECT COUNT(*) FROM hafd.hive_state);
    IF (SELECT COUNT(*) FROM hafd.hive_state) = 0 THEN
        INSERT INTO hafd.hive_state VALUES (1, NULL, FALSE);
    END IF;
END $$;

-- Load test utilities
\ir ../test_tools.sql

-- Test set_irreversible: verifies that calling set_irreversible(8) properly marks
-- block 8 as irreversible from the top fork (fork 3) and removes orphaned fork data.
--
-- Initial state (created by haf_admin_test_given):
-- - Fork 1 (main): blocks 6-9 - this continues from irreversible blocks 1-5
-- - Fork 2: splits from fork 1 at block 7, has blocks 7-9
-- - Fork 3: splits from fork 2 at block 8, has blocks 8-10 (this is the winning fork)
-- - Irreversible: blocks 1-5 (fork_id=0)
--
-- After set_irreversible(8):
-- For each block_num <= 8, we keep only the highest fork_id (canonical version).
-- - Block 6: fork 1 kept (only version)
-- - Block 7: fork 2 kept (higher than fork 1), fork 1 deleted
-- - Block 8: fork 3 kept (highest), fork 1 and 2 deleted
-- - Blocks 9+: all kept (above irreversible, no cleanup yet)


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', 'a' );

    PERFORM test.create_operation_types();

    -- Create forks 2 and 3
    -- Fork 2 starts at block 7 (diverges from fork 1)
    -- Fork 3 starts at block 8 (diverges from fork 2, becomes canonical)
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 7, '2020-06-22 19:10:25-07'::timestamp),
           (3, 8, '2020-06-22 19:10:26-07'::timestamp);

    -- Irreversible blocks 1-5 (fork_id=0)
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(3, 0), '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(4, 0), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(5, 0), '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES
          (1, 'u1', hafd.make_block_id(1, 0))
        , (2, 'u2', hafd.make_block_id(2, 0))
        , (3, 'u3', hafd.make_block_id(3, 0))
        , (4, 'u4', hafd.make_block_id(4, 0))
        , (5, 'u5', hafd.make_block_id(5, 0))
    ;

    INSERT INTO hafd.transactions
    VALUES
          ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(4, 0), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(5, 0), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
          ( '\xDEED10', '\xBAAD10', hafd.make_block_id(1, 0) )
        , ( '\xDEED20', '\xBAAD20', hafd.make_block_id(2, 0) )
        , ( '\xDEED30', '\xBAAD30', hafd.make_block_id(3, 0) )
        , ( '\xDEED40', '\xBAAD40', hafd.make_block_id(4, 0) )
        , ( '\xDEED50', '\xBAAD50', hafd.make_block_id(5, 0) )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_pos, body_binary, id)
    VALUES
          ( hafd.make_block_id(1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(1, 1, 0) )
        , ( hafd.make_block_id(2, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(2, 1, 0) )
        , ( hafd.make_block_id(3, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(3, 1, 0) )
        , ( hafd.make_block_id(4, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(4, 1, 0) )
        , ( hafd.make_block_id(5, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(5, 1, 0) )
    ;

    INSERT INTO hafd.account_operations(block_id, seq_in_block, account_id, transacting_account_id, account_op_seq_no)
    VALUES
          ( hafd.make_block_id(1, 0), 1, 1, 1, 1 )
        , ( hafd.make_block_id(2, 0), 1, 1, 1, 2 )
        , ( hafd.make_block_id(2, 0), 1, 2, 2, 1 )
        , ( hafd.make_block_id(3, 0), 1, 3, 3, 1 )
        , ( hafd.make_block_id(4, 0), 1, 4, 4, 1 )
    ;

    INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
    VALUES
          ( 1, hafd.make_block_id(1, 0), 1 )
        , ( 2, hafd.make_block_id(2, 0), 1 )
        , ( 3, hafd.make_block_id(3, 0), 1 )
        , ( 4, hafd.make_block_id(4, 0), 1 )
        , ( 5, hafd.make_block_id(5, 0), 1 )
    ;

    -- Fork 1: blocks 6-9 (this is the main continuation)
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(6, 1), '\xBADD61', '\xCAFE61', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(7, 1), '\xBADD71', '\xCAFE71', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 1), '\xBADD81', '\xCAFE81', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 1), '\xBADD91', '\xCAFE91', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES
          (6, 'u6_1', hafd.make_block_id(6, 1))
        , (7, 'u7_1', hafd.make_block_id(7, 1))
        , (8, 'u8_1', hafd.make_block_id(8, 1))
        , (9, 'u9_1', hafd.make_block_id(9, 1))
    ;

    INSERT INTO hafd.transactions
    VALUES
          ( hafd.make_block_id(6, 1), 0::SMALLINT, '\xDEED61', 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(7, 1), 0::SMALLINT, '\xDEED71', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(8, 1), 0::SMALLINT, '\xDEED81', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(9, 1), 0::SMALLINT, '\xDEED91', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
          ( '\xDEED61', '\xBEEF61', hafd.make_block_id(6, 1) )
        , ( '\xDEED71', '\xBEEF71', hafd.make_block_id(7, 1) )
        , ( '\xDEED81', '\xBEEF81', hafd.make_block_id(8, 1) )
        , ( '\xDEED91', '\xBEEF91', hafd.make_block_id(9, 1) )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_pos, body_binary, id)
    VALUES
          ( hafd.make_block_id(6, 1), 0, 0, '{"type":"system_warning_operation","value":{"message":"SIX1 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(6, 1, 0) )
        , ( hafd.make_block_id(7, 1), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN1 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 1, 0) )
        , ( hafd.make_block_id(8, 1), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT1 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 1, 0) )
        , ( hafd.make_block_id(9, 1), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE1 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(9, 1, 0) )
    ;

    INSERT INTO hafd.account_operations(block_id, seq_in_block, account_id, transacting_account_id, account_op_seq_no)
    VALUES
          ( hafd.make_block_id(6, 1), 1, 6, 6, 1 )
    ;

    INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
    VALUES
          ( 6, hafd.make_block_id(6, 1), 1 )
        , ( 7, hafd.make_block_id(7, 1), 1 )
        , ( 8, hafd.make_block_id(8, 1), 1 )
        , ( 9, hafd.make_block_id(9, 1), 1 )
    ;

    -- Fork 2: blocks 7-9 (diverges from fork 1 at block 7)
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(7, 2), '\xBADD72', '\xCAFE72', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(8, 2), '\xBADD82', '\xCAFE82', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 2), '\xBADD92', '\xCAFE92', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES
          (7, 'u7_2', hafd.make_block_id(7, 2))
        , (8, 'u8_2', hafd.make_block_id(8, 2))
        , (9, 'u9_2', hafd.make_block_id(9, 2))
    ;

    INSERT INTO hafd.transactions
    VALUES
          ( hafd.make_block_id(7, 2), 0::SMALLINT, '\xDEED72', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(7, 2), 1::SMALLINT, '\xDEED72B1', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(8, 2), 0::SMALLINT, '\xDEED82', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(9, 2), 0::SMALLINT, '\xDEED92', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
          ( '\xDEED72', '\xBEEF72', hafd.make_block_id(7, 2) )
        , ( '\xDEED72', '\xBEEF73', hafd.make_block_id(7, 2) ) -- Same hash, different signature (multisig)
        , ( '\xDEED82', '\xBEEF82', hafd.make_block_id(8, 2) )
        , ( '\xDEED92', '\xBEEF92', hafd.make_block_id(9, 2) )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_pos, body_binary, id)
    VALUES
          ( hafd.make_block_id(7, 2), 0, 0, '{"type":"system_warning_operation","value":{"message":"SEVEN2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 1, 0) )
        , ( hafd.make_block_id(7, 2), 0, 1, '{"type":"system_warning_operation","value":{"message":"SEVEN21 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(7, 2, 1) )
        , ( hafd.make_block_id(8, 2), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 1, 0) )
        , ( hafd.make_block_id(9, 2), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE2 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(9, 1, 0) )
    ;

    INSERT INTO hafd.account_operations(block_id, seq_in_block, account_id, transacting_account_id, account_op_seq_no)
    VALUES
          ( hafd.make_block_id(7, 2), 1, 4, 4, 2 )
        , ( hafd.make_block_id(7, 2), 1, 7, 7, 1 )
    ;

    INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
    VALUES
          ( 7, hafd.make_block_id(7, 2), 1 )
        , ( 8, hafd.make_block_id(7, 2), 2 )
        , ( 9, hafd.make_block_id(8, 2), 1 )
        , ( 10, hafd.make_block_id(9, 2), 1 )
    ;

    -- Fork 3: blocks 8-10 (this is the winning fork)
    INSERT INTO hafd.blocks
    VALUES
          ( hafd.make_block_id(8, 3), '\xBADD83', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(9, 3), '\xBADD93', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES
          (8, 'u8_3', hafd.make_block_id(8, 3))
        , (9, 'u9_3', hafd.make_block_id(9, 3))
        , (10, 'u10_3', hafd.make_block_id(10, 3))
    ;

    INSERT INTO hafd.transactions
    VALUES
          ( hafd.make_block_id(8, 3), 0::SMALLINT, '\xDEED88', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(9, 3), 0::SMALLINT, '\xDEED99', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF' )
        , ( hafd.make_block_id(10, 3), 0::SMALLINT, '\xDEED1102', 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
          ( '\xDEED88', '\xBEEF83', hafd.make_block_id(8, 3) )
        , ( '\xDEED99', '\xBEEF93', hafd.make_block_id(9, 3) )
        , ( '\xDEED1102', '\xBEEF13', hafd.make_block_id(10, 3) )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_pos, body_binary, id)
    VALUES
          ( hafd.make_block_id(8, 3), 0, 0, '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 1, 0) )
        , ( hafd.make_block_id(9, 3), 0, 0, '{"type":"system_warning_operation","value":{"message":"NINE3 OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(9, 1, 0) )
        , ( hafd.make_block_id(10, 3), 0, 0, '{"type":"system_warning_operation","value":{"message":"TEN OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(10, 1, 0) )
    ;

    INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
    VALUES
          ( 9, hafd.make_block_id(8, 3), 1 )
        , ( 10, hafd.make_block_id(9, 3), 1 )
        , ( 11, hafd.make_block_id(10, 3), 1 )
    ;

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);

    -- Set state to LIVE to enable orphan fork cleanup
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
    PERFORM hive.set_irreversible( 8 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    r RECORD;
BEGIN
    -- After set_irreversible(8):
    -- For each block_num <= 8, we keep only the block with the highest fork_id.
    -- Blocks above 8 (blocks 9-10) are not cleaned yet.
    --
    -- Expected blocks:
    -- - Blocks 1-5: fork_id=0 (5 blocks, original irreversible)
    -- - Block 6: fork_id=1 (only version)
    -- - Block 7: fork_id=2 (fork 1 deleted, fork 2 kept as highest)
    -- - Block 8: fork_id=3 (fork 1, 2 deleted, fork 3 kept as highest)
    -- - Blocks 9: fork_id=1, 2, 3 (all kept, above irreversible)
    -- - Block 10: fork_id=3 (only version, above irreversible)
    -- Total: 5 + 1 + 1 + 1 + 3 + 1 = 12 blocks

    -- Check blocks
    ASSERT EXISTS( SELECT * FROM hafd.blocks ), 'No blocks';
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks ) = 12, 'Expected 12 total blocks after cleanup';

    -- Verify blocks 1-5 are fork_id=0
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hafd.block_id_to_fork(block_id) = 0 ) = 5, 'Expected 5 blocks with fork_id=0';

    -- Verify block 6 is fork_id=1 (only version, kept)
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 6 ) = 1, 'Expected 1 block at block_num=6';
    ASSERT ( SELECT hafd.block_id_to_fork(block_id) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 6 ) = 1, 'Block 6 should be fork_id=1';

    -- Verify block 7 is fork_id=2 (fork 1 was orphaned)
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 7 ) = 1, 'Expected 1 block at block_num=7';
    ASSERT ( SELECT hafd.block_id_to_fork(block_id) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 7 ) = 2, 'Block 7 should be fork_id=2';

    -- Verify block 8 is fork_id=3 (fork 1, 2 were orphaned)
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 8 ) = 1, 'Expected 1 block at block_num=8';
    ASSERT ( SELECT hafd.block_id_to_fork(block_id) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 8 ) = 3, 'Block 8 should be fork_id=3';
    ASSERT ( SELECT hash FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 8 ) = '\xBADD83'::bytea, 'Block 8 hash incorrect';
    ASSERT ( SELECT producer_account_id FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 8 ) = 6, 'Block 8 producer incorrect';

    -- Verify blocks 9 still have all 3 versions (above irreversible, not cleaned)
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 9 ) = 3, 'Expected 3 blocks at block_num=9';

    -- Verify block 10 exists
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 10 ) = 1, 'Expected 1 block at block_num=10';

    -- Check transactions - same pattern
    ASSERT EXISTS( SELECT * FROM hafd.transactions ), 'No transactions';
    -- 5 (fork 0) + 1 (block 6, fork 1) + 2 (block 7, fork 2) + 1 (block 8, fork 3) + ...
    -- Fork 2 block 7 had 2 transactions
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions WHERE hafd.block_id_to_num(block_id) = 7 ) = 2, 'Expected 2 transactions at block 7';

    -- Check that block 8 transaction is from fork 3
    ASSERT ( SELECT trx_hash FROM hafd.transactions WHERE hafd.block_id_to_num(block_id) = 8 AND hafd.block_id_to_fork(block_id) = 3 ) = '\xDEED88'::bytea, 'Block 8 transaction hash incorrect';

    -- Check operations
    ASSERT EXISTS( SELECT * FROM hafd.operations ), 'No operations';

    -- Verify block 8 operation is from fork 3
    ASSERT ( SELECT body_binary FROM hafd.operations WHERE hafd.block_id_to_num(block_id) = 8 AND hafd.block_id_to_fork(block_id) = 3 ) = '{"type":"system_warning_operation","value":{"message":"EIGHT3 OPERATION"}}' :: jsonb :: hafd.operation, 'Block 8 operation should be from fork 3';

    -- Verify block 7 has 2 operations from fork 2 (fork 1 was deleted)
    ASSERT ( SELECT COUNT(*) FROM hafd.operations WHERE hafd.block_id_to_num(block_id) = 7 ) = 2, 'Block 7 should have 2 operations (from fork 2)';

    -- Check accounts
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE hafd.block_id_to_fork(block_id) = 0 ) = 5, 'Expected 5 accounts with fork_id=0';
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE hafd.block_id_to_num(block_id) = 6 ) = 1, 'Expected 1 account at block 6';
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE hafd.block_id_to_num(block_id) = 7 ) = 1, 'Expected 1 account at block 7 (fork 2)';
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE hafd.block_id_to_num(block_id) = 8 AND hafd.block_id_to_fork(block_id) = 3 ) = 1, 'Expected 1 account at block 8 fork 3';

    -- Check applied_hardforks
    ASSERT EXISTS( SELECT * FROM hafd.applied_hardforks ), 'No applied_hardforks';

    -- Verify hardfork from fork 3 block 8 exists (hardfork 9)
    ASSERT ( SELECT COUNT(*) FROM hafd.applied_hardforks WHERE hafd.block_id_to_num(block_id) = 8 AND hafd.block_id_to_fork(block_id) = 3 ) = 1, 'Expected 1 hardfork at block 8 fork 3';

    -- Verify consistent_block was updated
    ASSERT ( SELECT hafd.block_id_to_num(consistent_block) FROM hafd.hive_state ) = 8, 'consistent_block should be 8';
END;
$BODY$
;
