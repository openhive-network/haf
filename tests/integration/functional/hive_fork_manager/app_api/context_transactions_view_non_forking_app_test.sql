-- Test for non-forking context-specific transactions_view
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', _schema => 'a',_is_forking => FALSE );

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    -- Create irreversible blocks 1-4
    PERFORM test.create_blocks(1, 4);

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;

    -- Create irreversible transactions 1-4
    PERFORM test.create_transactions(1, 4);

    -- Reversible blocks for fork 1 (blocks 4-7)
    PERFORM test.create_blocks_reversible(4, 7, 1);

    -- Reversible blocks for fork 2 (blocks 7-9)
    PERFORM test.create_blocks_reversible(7, 9, 2);

    -- Reversible blocks for fork 3 (blocks 8-10)
    PERFORM test.create_blocks_reversible(8, 10, 3);

    -- Reversible transactions for fork 1
    PERFORM test.create_transactions_reversible(4, 7, 1);

    -- Reversible transactions for fork 2
    PERFORM test.create_transactions_reversible(7, 9, 2);

    -- Reversible transactions for fork 3
    PERFORM test.create_transactions_reversible(8, 10, 3);

    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 8;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Verify context transactions_view exists
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='transactions_view' ), 'No context transactions view';

    -- Verify non-forking context view does not use reversible data
    ASSERT NOT EXISTS (SELECT definition
                       FROM pg_views
                       WHERE schemaname = 'a'
                         AND viewname = 'transactions_view'
                         AND definition ILIKE '%hafd.transactions_reversible%'
    ), 'The view uses reversible data';

    -- Non-forking context with irreversible_block=4 should see transactions 1-4
    ASSERT ( SELECT COUNT(*) FROM a.transactions_view ) = 4, 'Wrong number of rows in non-forking context transactions view';

    -- Verify block range
    ASSERT ( SELECT MIN(block_num) FROM a.transactions_view ) = 1, 'Wrong min block';
    ASSERT ( SELECT MAX(block_num) FROM a.transactions_view ) = 4, 'Wrong max block';

    -- Verify all expected transactions are present
    ASSERT ( SELECT COUNT(*) FROM a.transactions_view WHERE block_num BETWEEN 1 AND 4 ) = 4, 'Missing transactions';
END
$BODY$
;
