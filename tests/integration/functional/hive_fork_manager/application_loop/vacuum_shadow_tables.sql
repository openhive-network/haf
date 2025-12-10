CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create pgstattuple extension for dead tuple inspection
    CREATE EXTENSION IF NOT EXISTS pgstattuple;
    -- Grant execute permission to alice user for pgstattuple function
    GRANT EXECUTE ON FUNCTION pgstattuple(regclass) TO alice;
    GRANT EXECUTE ON FUNCTION pgstattuple(text) TO alice;

    -- Create blocks for testing - need blocks up to 1202
    -- Vacuum triggers when: is_livesync AND current_block_num % 1200 = 0
    INSERT INTO hafd.blocks
    SELECT
           gs AS block_num
         , '\xBADD10'
         , '\xCAFE10'
         , '2016-06-22 19:10:21-07'::timestamp
         , 5
         , '\x4007'
         , E'[]'
         , '\x2157'
         , 'STM65w'
         , 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000
    FROM generate_series(1, 1202) AS gs;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1);

    -- Set all blocks as irreversible
    PERFORM hive.set_irreversible( 1202 );
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    -- Use a massive stage with very high min_distance so we're immediately in livesync
    -- min_distance = 10000 means massive only when > 10000 blocks from head
    -- With head = 1202, we're only 1202 blocks from head, so we go straight to live_stage
    __alice_stages hafd.application_stages :=
        ARRAY[
            hive.stage('massive', 10000, 1000)
            , hafd.live_stage()
        ];
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );

    -- Create application tables that will have shadow tables
    CREATE TABLE alice.accounts( id INTEGER PRIMARY KEY, name TEXT );
    CREATE TABLE alice.transactions( id INTEGER PRIMARY KEY, amount BIGINT );

    -- Register the tables to create shadow tables
    PERFORM hive.app_register_table( 'alice', 'accounts', 'alice' );
    PERFORM hive.app_register_table( 'alice', 'transactions', 'alice' );
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
    __current_block INTEGER;
    __last_vacuum_block INTEGER;
    __shadow_accounts_count INTEGER;
    __dead_tuples_before BIGINT;
    __dead_tuples_after BIGINT;
    __table_len_before BIGINT;
    __table_len_after BIGINT;
    __current_stage TEXT;
BEGIN
    -- Install mock for head block and set to 1202 (all blocks available)
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num(1202);

    -- Verify shadow tables exist (they were created when tables were registered)
    ASSERT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'hafd' AND table_name = 'shadow_alice_accounts'
    ), 'Shadow table shadow_alice_accounts should exist';

    -- Insert test data directly into shadow table to simulate accumulated changes
    INSERT INTO hafd.shadow_alice_accounts (id, name, hive_rowid, hive_block_num, hive_operation_type)
    SELECT gs, 'user' || gs, gs, 100, 'INSERT'::hafd.trigger_operation
    FROM generate_series(1, 1000) AS gs;

    RAISE NOTICE 'Inserted 1000 rows into shadow_alice_accounts';

    -- Delete all rows to create dead tuples
    DELETE FROM hafd.shadow_alice_accounts;

    -- Commit to make dead tuples visible
    COMMIT;

    -- Check dead tuple count before vacuum
    SELECT dead_tuple_count, table_len INTO __dead_tuples_before, __table_len_before
    FROM pgstattuple('hafd.shadow_alice_accounts');

    RAISE NOTICE 'Before vacuum - dead_tuple_count: %, table_len: %', __dead_tuples_before, __table_len_before;

    ASSERT __table_len_before > 8192, 'Table should have grown from inserts, got table_len: ' || __table_len_before;

    -- Process blocks 1-1200 using _override_max_batch to control batch size
    -- Since we're in livesync (massive stage has min_distance=10000), we can override batch size
    -- First iteration: process blocks 1-1200
    CALL hive.app_next_iteration( ARRAY['alice']::hive.contexts_group, __range_placeholder, 1200 );

    SELECT current_block_num INTO __current_block FROM hafd.contexts WHERE name = 'alice';
    SELECT hive.get_current_stage_name('alice') INTO __current_stage;
    RAISE NOTICE 'After iteration 1: current_block=%, stage=%, range=%-% ',
        __current_block, __current_stage, __range_placeholder.first_block, __range_placeholder.last_block;

    -- Verify we're in livesync stage
    ASSERT __current_stage = 'live', 'Should be in live stage, got: ' || COALESCE(__current_stage, 'NULL');

    -- Second iteration: this should trigger vacuum because:
    -- 1. There's a pending transaction (from processing blocks)
    -- 2. current_block_num = 1200, 1200 % 1200 = 0
    -- 3. is_livesync = TRUE (we're in live stage)
    CALL hive.app_next_iteration( ARRAY['alice']::hive.contexts_group, __range_placeholder, 1200 );

    SELECT current_block_num, (loop).last_shadow_vacuum_block INTO __current_block, __last_vacuum_block
    FROM hafd.contexts WHERE name = 'alice';
    RAISE NOTICE 'After iteration 2: current_block=%, last_shadow_vacuum_block=%',
        __current_block, COALESCE(__last_vacuum_block::TEXT, 'NULL');

    -- Verify vacuum was triggered (last_shadow_vacuum_block should be set)
    -- Note: last_shadow_vacuum_block is set to the last block of the range processed in that iteration
    ASSERT __last_vacuum_block IS NOT NULL, 'last_shadow_vacuum_block should be set after vacuum ran';
    ASSERT __last_vacuum_block >= 1200, 'last_shadow_vacuum_block should be >= 1200, got: ' || __last_vacuum_block;

    -- Check dead tuple count after vacuum
    SELECT dead_tuple_count, table_len INTO __dead_tuples_after, __table_len_after
    FROM pgstattuple('hafd.shadow_alice_accounts');

    RAISE NOTICE 'After vacuum - dead_tuple_count: %, table_len: %', __dead_tuples_after, __table_len_after;

    -- VACUUM FULL should have removed dead tuples and reclaimed space
    ASSERT __dead_tuples_after = 0, 'Dead tuples should be 0 after VACUUM FULL, got: ' || __dead_tuples_after;
    ASSERT __table_len_after <= 8192, 'Table should be minimal size after VACUUM FULL, got: ' || __table_len_after;

    -- Verify table is accessible and empty
    SELECT COUNT(*) INTO __shadow_accounts_count FROM hafd.shadow_alice_accounts;
    ASSERT __shadow_accounts_count = 0, 'Shadow table should be empty after deletes';

    RAISE NOTICE 'SUCCESS: Dead tuples removed via app_next_iteration. table_len before: %, after: %',
        __table_len_before, __table_len_after;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __shadow_accounts_exists BOOLEAN;
    __shadow_transactions_exists BOOLEAN;
    __last_vacuum_block INTEGER;
    __dead_tuple_count BIGINT;
    __table_len BIGINT;
BEGIN
    -- Verify shadow tables still exist after vacuum
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'hafd' AND table_name = 'shadow_alice_accounts'
    ) INTO __shadow_accounts_exists;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'hafd' AND table_name = 'shadow_alice_transactions'
    ) INTO __shadow_transactions_exists;

    ASSERT __shadow_accounts_exists, 'Shadow table shadow_alice_accounts should exist after vacuum';
    ASSERT __shadow_transactions_exists, 'Shadow table shadow_alice_transactions should exist after vacuum';

    -- Verify vacuum was triggered through app_next_iteration
    SELECT (loop).last_shadow_vacuum_block INTO __last_vacuum_block
    FROM hafd.contexts WHERE name = 'alice';
    ASSERT __last_vacuum_block >= 1200, 'last_shadow_vacuum_block should be >= 1200, got: ' || COALESCE(__last_vacuum_block::TEXT, 'NULL');

    -- Final verification: no dead tuples and minimal table size after VACUUM FULL
    SELECT dead_tuple_count, table_len INTO __dead_tuple_count, __table_len
    FROM pgstattuple('hafd.shadow_alice_accounts');

    ASSERT __dead_tuple_count = 0, 'Final check: dead_tuple_count should be 0, got: ' || __dead_tuple_count;
    ASSERT __table_len <= 8192, 'Final check: table_len should be minimal, got: ' || __table_len;

    RAISE NOTICE 'Final verification passed: last_shadow_vacuum_block=%, dead_tuple_count=%, table_len=%',
        __last_vacuum_block, __dead_tuple_count, __table_len;
END;
$BODY$;
