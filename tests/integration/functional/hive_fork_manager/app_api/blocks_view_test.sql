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
    INSERT INTO hafd.accounts(id, name, block_num) VALUES (5, 'initminer', 1);

    -- Reversible blocks for fork 1: blocks 4-9
    PERFORM test.create_blocks_reversible(4, 9, 1);

    -- Reversible blocks for fork 2: blocks 7-9 (overrides fork 1 for these blocks)
    PERFORM test.create_blocks_reversible(7, 9, 2);

    -- Reversible blocks for fork 3: blocks 8-10
    PERFORM test.create_blocks_reversible(8, 10, 3);

    UPDATE hafd.hive_state SET consistent_block = 5;
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
    -- Should have blocks 1-10: 5 irreversible + fork 3 (8-10) which is current top fork
    ASSERT ( SELECT COUNT(*) FROM hive.blocks_view ) = 10, 'Wrong number of rows in blocks_view';

    -- Verify all expected blocks are present
    ASSERT ( SELECT COUNT(*) FROM hive.blocks_view WHERE num BETWEEN 1 AND 5 ) = 5, 'Missing irreversible blocks';
    ASSERT ( SELECT COUNT(*) FROM hive.blocks_view WHERE num BETWEEN 6 AND 10 ) = 5, 'Missing reversible blocks';

    -- Verify irreversible_blocks_view exists
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='irreversible_blocks_view' ), 'No irreversible blocks view';

    -- Verify irreversible_blocks_view contains expected number of rows (blocks 1-5)
    ASSERT ( SELECT COUNT(*) FROM hive.irreversible_blocks_view ) = 5, 'Wrong number of irreversible rows';

    -- Verify irreversible blocks have correct block numbers
    ASSERT ( SELECT MIN(num) FROM hive.irreversible_blocks_view ) = 1, 'Wrong min block in irreversible view';
    ASSERT ( SELECT MAX(num) FROM hive.irreversible_blocks_view ) = 5, 'Wrong max block in irreversible view';
END
$BODY$
;
