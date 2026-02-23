-- Test for hive.blocks_view
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE table1( id INT ) INHERITS( a.context );

    -- Setup standard view test scenario:
    -- Forks 2 and 3 at blocks 6 and 7
    -- Irreversible blocks 1-5
    -- Reversible blocks: fork 1 (4-9), fork 2 (7-9), fork 3 (8-10)
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible blocks 1-5
    PERFORM test.create_blocks(1, 5);

    -- Create initminer account
    INSERT INTO hafd.accounts(id, name, block_id) VALUES (5, 'initminer', hafd.make_block_id(1, 0));

    -- Reversible blocks for fork 1: blocks 4-9
    PERFORM test.create_blocks_reversible(4, 9, 1);

    -- Reversible blocks for fork 2: blocks 7-9 (overrides fork 1 for these blocks)
    PERFORM test.create_blocks_reversible(7, 9, 2);

    -- Reversible blocks for fork 3: blocks 8-10
    PERFORM test.create_blocks_reversible(8, 10, 3);

    -- Mark blocks that have multiple fork versions as conflicts
    INSERT INTO hafd.block_conflicts (block_num)
    VALUES (4), (5), (7), (8), (9)
    ON CONFLICT DO NOTHING;

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(5, 0);
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Verify blocks_view exists
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='blocks_view' ), 'No context blocks view';

    -- Verify blocks_view contains expected number of rows
    ASSERT ( SELECT COUNT(*) FROM hive.blocks_view ) = 10, 'Wrong number of rows in blocks_view';

    -- Verify fork conflict resolution: canonical block = highest fork_id per block_num
    -- Blocks 1-3: irreversible only (fork_id=0), no conflicts
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 1 ) = test.expected_block_hash(1), 'Wrong hash for block 1 (irreversible)';
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 2 ) = test.expected_block_hash(2), 'Wrong hash for block 2 (irreversible)';
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 3 ) = test.expected_block_hash(3), 'Wrong hash for block 3 (irreversible)';

    -- Block 4-5: conflict between fork 0 (irreversible) and fork 1 => fork 1 wins
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 4 ) = test.expected_block_hash(4, 1), 'Wrong hash for block 4: fork 1 should win over fork 0';
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 5 ) = test.expected_block_hash(5, 1), 'Wrong hash for block 5: fork 1 should win over fork 0';

    -- Block 6: fork 1 only, no conflict
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 6 ) = test.expected_block_hash(6, 1), 'Wrong hash for block 6 (fork 1 only)';

    -- Block 7: conflict between fork 1 and fork 2 => fork 2 wins
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 7 ) = test.expected_block_hash(7, 2), 'Wrong hash for block 7: fork 2 should win over fork 1';

    -- Blocks 8-9: conflict between fork 1, fork 2, and fork 3 => fork 3 wins
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 8 ) = test.expected_block_hash(8, 3), 'Wrong hash for block 8: fork 3 should win over forks 1 and 2';
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 9 ) = test.expected_block_hash(9, 3), 'Wrong hash for block 9: fork 3 should win over forks 1 and 2';

    -- Block 10: fork 3 only, no conflict
    ASSERT ( SELECT hash FROM hive.blocks_view WHERE num = 10 ) = test.expected_block_hash(10, 3), 'Wrong hash for block 10 (fork 3 only)';

    -- Verify irreversible_blocks_view
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='irreversible_blocks_view' ), 'No irreversible blocks view';
    ASSERT ( SELECT COUNT(*) FROM hive.irreversible_blocks_view ) = 5, 'Wrong number of irreversible rows';

    -- Verify irreversible blocks are from fork 0 (original irreversible data)
    ASSERT ( SELECT hash FROM hive.irreversible_blocks_view WHERE num = 1 ) = test.expected_block_hash(1), 'Wrong hash for irreversible block 1';
    ASSERT ( SELECT hash FROM hive.irreversible_blocks_view WHERE num = 5 ) = test.expected_block_hash(5), 'Wrong hash for irreversible block 5';
END
$BODY$
;
