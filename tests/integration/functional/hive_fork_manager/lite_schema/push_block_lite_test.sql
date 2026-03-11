
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hafd.blocks%ROWTYPE;
    __transaction1 hafd.transactions%ROWTYPE;
    __operation1 hafd.operations%ROWTYPE;
    __signatures1 hafd.transactions_multisig%ROWTYPE;
    __account1 hafd.accounts%ROWTYPE;
    __account_operation1 hafd.account_operations%ROWTYPE;
    __applied_hardforks1 hafd.applied_hardforks%ROWTYPE;
BEGIN
    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    __transaction1 = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
    __operation1 = ( hafd.operation_id(101, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation, NULL );
    __signatures1 = ( '\xDEED', '\xFEED' );
    __account1 = ( 1, 'alice', 101 );
    __account_operation1 = ( 1, 1, 1, hafd.operation_id(101, 0), 1 );
    __applied_hardforks1 = (1, 101, 1);
    PERFORM hive.push_block(
          __block
        , ARRAY[ __transaction1 ]
        , ARRAY[ __signatures1 ]
        , ARRAY[ __operation1 ]
        , ARRAY[ __account1 ]
        , ARRAY[ __account_operation1 ]
        , ARRAY[ __applied_hardforks1 ]
    );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- In lite mode, push_block delegates to push_block_lite which writes directly to irreversible tables
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE num = 101 ) = 1, 'Block not in irreversible table';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions WHERE block_num = 101 ) = 1, 'Transaction not in irreversible table';
    ASSERT ( SELECT COUNT(*) FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) = 101 ) = 1, 'Operation not in irreversible table';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions_multisig WHERE trx_hash = '\xDEED' ) = 1, 'Signature not in irreversible table';
    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE name = 'alice' AND block_num = 101 ) = 1, 'Account not in irreversible table';
    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations WHERE account_id = 1 ) = 1, 'Account operation not in irreversible table';
    ASSERT ( SELECT COUNT(*) FROM hafd.applied_hardforks WHERE hardfork_num = 1 AND block_num = 101 ) = 1, 'Applied hardfork not in irreversible table';

    -- Reversible tables should not exist (they were dropped by enable_lite_schema)
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='blocks_reversible'), 'blocks_reversible should not exist';
END;
$BODY$
;
