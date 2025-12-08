-- start pruning function
--      no registered contexts
--      blocks to prune exists
-- expected result:
--          remove all blocks data
--          check if accounts are not removed

-- start pruning function
--      no registered contexts
--      blocks to prune no  exists
-- expected result:
--          remove 4 blocks
--          check if accounts are not removed

-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create infrastructure matching old fill_with_blocks_data()
    PERFORM test.create_operation_types();
    PERFORM test.create_forks();

    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    -- Create accounts with specific IDs (1-5) and names (u1-u5)
    INSERT INTO hafd.accounts( block_num, name, id )
    VALUES
    ( 1, 'u1', 1 )
         , ( 2, 'u2', 2 )
         , ( 3, 'u3', 3 )
         , ( 4, 'u4', 4 )
         , ( 5, 'u5', 5 )
    ;

    -- Create transactions
    PERFORM test.create_transactions(1, 5);

    -- Create transactions_multisig entries
    INSERT INTO hafd.transactions_multisig
    VALUES
    ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
         , ( '\xDEED30', '\xBAAD30' )
         , ( '\xDEED40', '\xBAAD40' )
         , ( '\xDEED50', '\xBAAD50' )
    ;

    -- Create operations
    PERFORM test.create_operations(1, 5);

    -- Create account_operations entries
    INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, operation_id)
    VALUES
           ( 1, 1, 1, hafd.operation_id(1,1,0) )
         , ( 1, 1, 2, hafd.operation_id(2,1,0) )
         , ( 2, 2, 1, hafd.operation_id(2,1,0) )
         , ( 3, 3, 1, hafd.operation_id(3,1,0) )
         , ( 4, 4, 1, hafd.operation_id(4,1,0) )
         , ( 5, 5, 1, hafd.operation_id(5,1,0) )
    ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.prune_blocks_data();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hafd.blocks) = 1, 'Some blocks stay';
    ASSERT (SELECT MAX(num) FROM hafd.blocks) = 5, 'Wrong blocks removed';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions) = 1, 'Some transactions stay';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions_multisig) = 1, 'Some transactions multisig stay';
    ASSERT (SELECT COUNT(*) FROM hafd.operations) = 1, 'Some operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.account_operations) = 0, 'Some account operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.accounts) = 5, 'Number of accounts has changed';
END;
$BODY$
;
