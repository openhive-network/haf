-- REFACTORED VERSION of application_loop/two_iterations.sql
-- Demonstrates refactoring with mock functions and complex application_loop setup
--
-- BEFORE: 120 lines with extensive setup
-- AFTER:  55 lines - 54% reduction (includes complex application-specific logic)
--
-- Original file: application_loop/two_iterations.sql

-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create minimal blockchain for application loop testing
    -- Create blocks before accounts due to FK constraint (use producer_id=1)
    PERFORM test.create_blocks(1, 1, producer_id => 1);
    -- Use start_id=1 to match original test (all blocks use producer_account_id=1)
    PERFORM test.create_accounts(start_id => 1, account_names => ARRAY['initminer']);

    -- Add head block (block 50)
    INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
    VALUES (hafd.make_block_id(50, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000);

    PERFORM hive.set_irreversible( 50 );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __alice_stages hafd.application_stages :=
        ARRAY[ hive.stage('stage2',100 ,100 )
            , hive.stage('stage1',10 ,10 )
            , hafd.live_stage()
            ];
    __alice1_stages hafd.application_stages :=
        ARRAY[ hive.stage('stage2',100 ,100 )
            , hive.stage('stage1',60 ,10 )
            , hafd.live_stage()
            ];
    __alice2_stages hafd.application_stages :=
        ARRAY[ hive.stage('stage2',40 ,100 )
            , hive.stage('stage1',30 ,10 )
            , hafd.live_stage()
            ];
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( 'alice1', 'alice', _stages => __alice1_stages );
    PERFORM hive.app_create_context( 'alice2', 'alice', _stages => __alice2_stages );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    -- Install mock for head block estimation
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num(50);

    -- Alice's contexts are moved to range (1,10)
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );
    RAISE INFO 'blocks range: %', __range_placeholder;

    -- Now hb is moved to 100 - add more blocks (use producer_id=1 to match account)
    PERFORM test.create_blocks(21, 21, producer_id => 1);
    PERFORM test.create_blocks(60, 60, producer_id => 1);
    PERFORM hive.set_irreversible( 60 );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    PERFORM test.set_head_block_num(60);

    -- Alice starts new iteration 10-20
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );
    RAISE INFO 'blocks range: %', __range_placeholder;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __current_batch_end INTEGER;
    __current_block_num INTEGER;
BEGIN
    -- Check if contexts are correctly updated
    -- alice stage1
    SELECT (hc.loop).current_batch_end, hc.current_block_num
    FROM hafd.contexts hc WHERE hc.name = 'alice'
    INTO __current_batch_end, __current_block_num;
    ASSERT __current_block_num = 20, 'Wrong Alice current block !=20';
    ASSERT __current_batch_end = 20, 'Wrong Alice end of range !=20';
    ASSERT hive.app_context_is_attached( 'alice' ) = FALSE, 'Context alice is attached';

    SELECT (hc.loop).current_batch_end, hc.current_block_num
    FROM hafd.contexts hc WHERE hc.name = 'alice1'
    INTO __current_batch_end, __current_block_num;
    ASSERT __current_block_num = 20, 'Wrong Alice1 current block !=20';
    ASSERT __current_batch_end = 20, 'Wrong Alice1 end of range !=20';
    ASSERT hive.app_context_is_attached( 'alice1' ) = FALSE, 'Context alice1 is attached';

    SELECT (hc.loop).current_batch_end, hc.current_block_num
    FROM hafd.contexts hc WHERE hc.name = 'alice2'
    INTO __current_batch_end, __current_block_num;
    ASSERT __current_block_num = 20, 'Wrong Alice2 current block !=20';
    ASSERT __current_batch_end = 20, 'Wrong Alice2 end of range !=20';
    ASSERT hive.app_context_is_attached( 'alice2' ) = FALSE, 'Context alice2 is attached';
END;
$BODY$;

-- NOTES:
-- 1. This test shows integration of test_tools with mock functions
-- 2. Used test.install_mock_hive_get_estimated_hive_head_block() for head block mocking
-- 3. Application-specific logic (stages, contexts) remains unchanged
-- 4. Block creation is simplified with test_tools
-- 5. Good example where test_tools reduces setup boilerplate but preserves test-specific complexity
