-- Test for hive.transactions_view
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Setup forks
    INSERT INTO hafd.fork(id, block_num, time_of_fork)
    VALUES (2, 6, '2020-06-22 19:10:25-07'::timestamp),
           (3, 7, '2020-06-22 19:10:25-07'::timestamp);

    -- Create irreversible blocks and transactions
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts(id, name, block_num) VALUES (5, 'initminer', 1);
    PERFORM test.create_transactions(1, 5);

    -- Reversible blocks for fork 1 (blocks 4-7)
    PERFORM test.create_blocks_reversible(4, 7, 1);
    PERFORM test.create_transactions_reversible(4, 7, 1);

    -- Reversible blocks for fork 2 (blocks 7-9)
    PERFORM test.create_blocks_reversible(7, 9, 2);
    PERFORM test.create_transactions_reversible(7, 9, 2);

    -- Reversible blocks for fork 3 (blocks 8-10) - current top fork
    PERFORM test.create_blocks_reversible(8, 10, 3);
    PERFORM test.create_transactions_reversible(8, 10, 3);

    UPDATE hafd.hive_state SET consistent_block = 5;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Verify transactions_view exists
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='transactions_view' ), 'No transactions view';

    -- Verify transactions_view has correct count
    -- Blocks 1-5 irreversible + fork 3 blocks 8-10 = 5 + 3 = 8 transactions
    -- Plus fork 2 blocks 7 = 1 more = depends on fork selection logic
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_view ) >= 8, 'Too few rows in transactions_view';

    -- Verify irreversible transactions view exists
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='irreversible_transactions_view' ), 'No irreversible transactions view';

    -- Verify irreversible transactions count (blocks 1-5)
    ASSERT ( SELECT COUNT(*) FROM hive.irreversible_transactions_view ) = 5, 'Wrong number of irreversible transactions';

    -- Verify block range in irreversible view
    ASSERT ( SELECT MIN(block_num) FROM hive.irreversible_transactions_view ) = 1, 'Wrong min block in irreversible view';
    ASSERT ( SELECT MAX(block_num) FROM hive.irreversible_transactions_view ) = 5, 'Wrong max block in irreversible view';
END
$BODY$
;
