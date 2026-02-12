-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'ZERO OPERATION', FALSE )
        , ( 1, 'ONE OPERATION', FALSE )
    ;

    INSERT INTO hafd.blocks
    VALUES
       ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
         , (6, 'alice', hafd.make_block_id(1, 0))
         , (7, 'bob', hafd.make_block_id(1, 0))
    ;

    INSERT INTO hafd.transactions
    VALUES
           ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
           ( '\xDEED10', '\xBAAD10', hafd.make_block_id(1, 0) )
         , ( '\xDEED20', '\xBAAD20', hafd.make_block_id(2, 0) )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_pos, body_binary, id)
    VALUES
           ( hafd.make_block_id(1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(1, 1, 0) )
         , ( hafd.make_block_id(2, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation, hafd.operation_id(2, 1, 0) )
    ;

    INSERT INTO hafd.accounts
    VALUES
             ( 1, 'userconsistent', hafd.make_block_id(1, 0))
           , ( 2, 'user', hafd.make_block_id(2, 0))
    ;

    INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, block_id, operation_id)
    VALUES
        ( 1, 1, 1, hafd.make_block_id(1, 0), hafd.operation_id(1, 1, 0) )
      , ( 2, 2, 1, hafd.make_block_id(2, 0), hafd.operation_id(2, 1, 0) )
    ;

    INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
    VALUES
        ( 1, hafd.make_block_id(1, 0), hafd.operation_id(1, 1, 0) )
      , ( 2, hafd.make_block_id(2, 0), hafd.operation_id(2, 1, 0) )
    ;

    -- here we simulate situation when hived claims recently only block 1
    -- block 2 was not claimed, and it is possible not all information about it was dumped - maybe hived crashes
    PERFORM hive.end_massive_sync( 1 );

    UPDATE hafd.hive_state SET is_dirty = TRUE;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.remove_inconsistent_irreversible_data();
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks ) = 1, 'Unexpected number of blocks';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions ) = 1, 'Unexpected number of transactions';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions_multisig ) = 1, 'Unexpected number of signatures';
    ASSERT ( SELECT COUNT(*) FROM hafd.operations ) = 1, 'Unexpected number of operations';
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts ) = 4, 'Unexpected number of accounts';
    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations ) = 1, 'Unexpected number of account_operations';
    ASSERT ( SELECT COUNT(*) FROM hafd.applied_hardforks ) = 1, 'Unexpected number of applied_hardforks';


    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE hafd.block_id_to_num(block_id) = 1 ) = 1, 'No blocks with num = 1';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions WHERE hafd.block_id_to_num(block_id) = 1 ) = 1, 'No transaction with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hafd.operations WHERE hafd.block_id_to_num(block_id) = 1 ) = 1, 'No operations with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE hafd.block_id_to_num(block_id) = 1 ) = 4, 'No account with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions_multisig WHERE trx_hash = '\xDEED10'::bytea ) = 1, 'No signatures with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations WHERE account_id = 1 ) = 1, 'No account_operations with account_id = 1';
    ASSERT ( SELECT COUNT(*) FROM hafd.applied_hardforks WHERE hafd.block_id_to_num(block_id) = 1 ) = 1, 'No applied_hardforks with block_num = 1';

END
$BODY$
;




