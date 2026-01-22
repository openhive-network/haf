-- Test remove_orphan_forks function with unified table architecture
-- Scenario: 3 contexts working on different forks
-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;

    PERFORM hive.app_create_context( 'context1' , 'a' );
    PERFORM hive.app_create_context( 'context2' , 'a' );
    PERFORM hive.app_create_context( 'context3' , 'a' );

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    -- Insert blocks into unified table
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

    -- Insert accounts
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

    -- Configure contexts on different forks
    UPDATE hafd.contexts SET fork_id = 1, irreversible_block = 6, current_block_num = 6 WHERE name = 'context1';
    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 8, current_block_num = 8 WHERE name = 'context2';
    UPDATE hafd.contexts SET fork_id = 3, irreversible_block = 9, current_block_num = 9 WHERE name = 'context3';

    -- SUMMARY:
    -- We have 3 forks: 1 (blocks: 4,5,6,7,10), 2 (blocks: 7,8,9), 3 (blocks: 8,9,10)
    -- 3 contexts working on fork/block: 1/6, 2/8, 3/9

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
    -- Orphan blocks at same block_num are removed (keeping highest fork_id)
    -- Context dependencies may affect what can be removed

    -- Verify fork 3 blocks remain (highest fork)
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(8, 3)), 'Fork 3 block 8 missing';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(9, 3)), 'Fork 3 block 9 missing';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(10, 3)), 'Fork 3 block 10 missing';

    -- Fork 1 block 7 should be removed (fork 2 has higher fork_id at block 7)
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 should be removed';

    -- Fork 2 block 8 should be removed (fork 3 has higher fork_id at block 8)
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(8, 2)), 'Fork 2 block 8 should be removed';

    -- Fork 1 blocks 4,5,6 should remain (no higher fork at these block_nums)
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(4, 1)), 'Fork 1 block 4 should remain';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(5, 1)), 'Fork 1 block 5 should remain';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE block_id = hafd.make_block_id(6, 1)), 'Fork 1 block 6 should remain';

    -- Verify accounts on orphan blocks are removed
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.accounts WHERE block_id = hafd.make_block_id(7, 1)), 'Fork 1 block 7 accounts removed';
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.accounts WHERE block_id = hafd.make_block_id(8, 2)), 'Fork 2 block 8 accounts removed';

END;
$BODY$
;
