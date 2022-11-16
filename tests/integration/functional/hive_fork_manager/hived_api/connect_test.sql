DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES (0, 'ZERO OPERATION', FALSE )
        , ( 1, 'ONE OPERATION', FALSE )
    ;

    INSERT INTO hive.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;

    INSERT INTO hive.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.transactions_multisig
    VALUES
           ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
    ;

    INSERT INTO hive.operations
    VALUES
           ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ZERO OPERATION' )
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ONE OPERATION' )
    ;

    INSERT INTO hive.accounts
    VALUES
          ( 1, 'userconsistent', 1)
        , ( 2, 'user', 2)
    ;

    INSERT INTO hive.account_operations
    VALUES
          ( 1, 1, 1, 1, 1)
        , ( 2, 2, 1, 2, 1)
    ;

    -- here we simulate situation when hived claims recently only block 1
    -- block 2 was not claimed, and it is possible not all information about it was dumped - maybe hived crashes
    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.update_irr_data_dirty(TRUE);
    
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.connect( '123456789', 100 );
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.blocks ) = 1, 'Unexpected number of blocks';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions ) = 1, 'Unexpected number of transactions';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig ) = 1, 'Unexpected number of signatures';
    ASSERT ( SELECT COUNT(*) FROM hive.operations ) = 1, 'Unexpected number of operations';
    ASSERT ( SELECT COUNT(*) FROM hive.accounts ) = 4, 'Unexpected number of accounts';
    ASSERT ( SELECT COUNT(*) FROM hive.account_operations ) = 1, 'Unexpected number of account_operations';

    ASSERT ( SELECT COUNT(*) FROM hive.blocks WHERE num = 1 ) = 1, 'No blocks with num = 1';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions WHERE block_num = 1 ) = 1, 'No transaction with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hive.operations WHERE block_num = 1 ) = 1, 'No operations with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig WHERE trx_hash = '\xDEED10'::bytea ) = 1, 'No signatures with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hive.accounts WHERE block_num = 1 ) = 4, 'No account with block_num = 1';
    ASSERT ( SELECT COUNT(*) FROM hive.account_operations WHERE account_id = 1 ) = 1, 'No account_operations with block_num = 1';

    ASSERT( SELECT COUNT(*) FROM hive.hived_connections ) = 1, 'No connection saved';
    ASSERT( SELECT COUNT(*) FROM hive.hived_connections WHERE block_num=100 AND git_sha='123456789' ) = 1, 'No expected connection saved';

    ASSERT( SELECT COUNT(*) FROM hive.fork WHERE id = 2 AND block_num = 100 ) = 1, 'No fork added after connection';

    ASSERT( SELECT is_dirty FROM hive.get_irr_data() ) = FALSE, 'Irreversible data are dirty';
END
$BODY$
;




