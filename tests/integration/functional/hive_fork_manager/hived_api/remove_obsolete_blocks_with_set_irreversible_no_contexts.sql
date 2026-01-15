-- Test remove_orphan_forks function with unified table architecture
-- Scenario: No contexts - all orphan forks can be cleaned immediately
-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
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

    -- SUMMARY:
    -- We have 3 forks: 1 (blocks: 4,5,6,7,10), 2 (blocks: 7,8,9), 3 (blocks: 8,9,10)
    -- No contexts - orphan removal can proceed without restrictions
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- block 8 becomes irreversible
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
    -- Blocks at same block_num: keep highest fork_id, remove others
    -- Block 7: fork 1 removed (fork 2 is higher), fork 2 kept
    -- Block 8: fork 2 removed (fork 3 is higher), fork 3 kept
    -- Blocks 4,5,6 on fork 1: kept (no higher fork)
    -- Block 10 fork 1: removed (fork 3 has block 10)

    -- Verify fork 3 blocks remain
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(8, 3)), 'Fork 3 block 8 missing';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(9, 3)), 'Fork 3 block 9 missing';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(10, 3)), 'Fork 3 block 10 missing';

    -- Fork 2 block 7 should remain (highest fork at block 7)
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(7, 2)), 'Fork 2 block 7 should remain';

    -- Fork 1 block 7 should be removed (orphan - fork 2 has higher fork_id at block 7)
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 should be removed';

    -- Fork 2 block 8 should be removed (orphan - fork 3 has higher fork_id at block 8)
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(8, 2)), 'Fork 2 block 8 should be removed';

    -- Fork 1 blocks 4,5,6 should remain (no higher fork at these block numbers)
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(4, 1)), 'Fork 1 block 4 should remain';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(5, 1)), 'Fork 1 block 5 should remain';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(6, 1)), 'Fork 1 block 6 should remain';

    -- Verify account data cleanup for removed blocks
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.accounts WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 accounts removed';
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.accounts WHERE block_id = hafd.make_block_id(8, 2)), 'Fork 2 block 8 accounts removed';

END;
$BODY$
;
