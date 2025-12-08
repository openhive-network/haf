-- start pruning function
--      registered two contexts on different current block
--      blocks to prune
-- expected result:
--          remove blocks lower than the lowest current block
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

    -- Create account_operations entries (up to block 4, matching old fill_with_blocks_data)
    INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, operation_id)
    VALUES
           ( 1, 1, 1, hafd.operation_id(1,1,0) )
         , ( 1, 1, 2, hafd.operation_id(2,1,0) )
         , ( 2, 2, 1, hafd.operation_id(2,1,0) )
         , ( 3, 3, 1, hafd.operation_id(3,1,0) )
         , ( 4, 4, 1, hafd.operation_id(4,1,0) )
    ;

    CREATE SCHEMA A;
    PERFORM hive.app_create_context(  _name =>'context1', _schema => 'a', _is_attached := FALSE );
    PERFORM hive.app_create_context(  _name =>'context2', _schema => 'a', _is_attached := FALSE );

    PERFORM hive.app_set_current_block_num( 'context1', 5 );
    PERFORM hive.app_set_current_block_num( 'context2', 4 );

    UPDATE hafd.contexts
    SET irreversible_block = 5
    WHERE name ='context1';

    UPDATE hafd.contexts
    SET irreversible_block = 3
    WHERE name ='context2';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.prune_blocks_data(2);
    -- the lowest context cb is 4, it means only blck: 1 must be removed
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hafd.blocks) = 3, 'Too much blocks stay';
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE num = 1), 'block 1 was not removed';

    ASSERT (SELECT COUNT(*) FROM hafd.transactions) = 3, 'Some transactions stay';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions_multisig) = 3, 'Some transactions multisig stay';
    ASSERT (SELECT COUNT(*) FROM hafd.operations) = 3, 'Some operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.account_operations) = 2, 'Some account operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.accounts) = 5, 'Number of accounts has changed';
END;
$BODY$
;
