
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive_data.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hive_data.blocks%ROWTYPE;
    __transaction1 hive_data.transactions%ROWTYPE;
    __transaction2 hive_data.transactions%ROWTYPE;
    __operation1_1 hive_data.operations%ROWTYPE;
    __operation2_1 hive_data.operations%ROWTYPE;
    __signatures1 hive_data.transactions_multisig%ROWTYPE;
    __signatures2 hive_data.transactions_multisig%ROWTYPE;
    __account1 hive_data.accounts%ROWTYPE;
    __account2 hive_data.accounts%ROWTYPE;
    __account_operation1 hive_data.account_operations%ROWTYPE;
    __account_operation2 hive_data.account_operations%ROWTYPE;
    __applied_hardforks1 hive_data.applied_hardforks%ROWTYPE;
    __applied_hardforks2 hive_data.applied_hardforks%ROWTYPE;
BEGIN
    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G' , 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    __transaction1 = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
    __transaction2 = ( 101, 1::SMALLINT, '\xBEEF', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xDEED' );
    __operation1_1 = ( hive.operation_id(101,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hive_data.operation );
    __operation2_1 = ( hive.operation_id(101,2,0), 1, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hive_data.operation );
    __signatures1 = ( '\xDEED', '\xFEED' );
    __signatures2 = ( '\xBEEF', '\xBABE' );
    __account1 = ( 1, 'alice', 101 );
    __account2 = ( 2, 'bob', 101 );
    __account_operation1 = ( 1, 1, hive.operation_id(101,1,0) );
    __account_operation2 = ( 2, 1, hive.operation_id(101,2,0) );
    __applied_hardforks1 = (1, 101, 1);
    __applied_hardforks2 = (2, 101, 2);
    PERFORM hive.push_block(
          __block
        , ARRAY[ __transaction1, __transaction2 ]
        , ARRAY[ __signatures1, __signatures2 ]
        , ARRAY[ __operation1_1, __operation2_1 ]
        , ARRAY[ __account1, __account2 ]
        , ARRAY[ __account_operation1, __account_operation2 ]
        , ARRAY[ __applied_hardforks1, __applied_hardforks2 ]
    );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hive_data.events_queue WHERE id = 1 AND event = 'NEW_BLOCK' AND block_num = 101 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hive_data.events_queue ) = 3, 'Unexpected number of events';

    ASSERT ( SELECT COUNT(*) FROM hive_data.blocks_reversible ) = 1, 'Unexpected number of blocks';
    ASSERT ( SELECT COUNT(*) FROM hive_data.transactions_reversible ) = 2, 'Unexpected number of transactions';
    ASSERT ( SELECT COUNT(*) FROM hive_data.transactions_multisig_reversible ) = 2, 'Unexpected number of signatures';
    ASSERT ( SELECT COUNT(*) FROM hive_data.operations_reversible ) = 2, 'Unexpected number of operations';

    ASSERT  ( SELECT COUNT(*) FROM hive_data.blocks_reversible
                    WHERE
                        num=101
                    AND hash='\xBADD'
                    AND prev='\xCAFE'
                    AND created_at='2016-06-22 19:10:25-07'::timestamp
                    AND producer_account_id=5
                    AND fork_id = 1
    ) = 1, 'Wrong block data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive_data.transactions_reversible
                    WHERE
                        block_num=101
                    AND trx_in_block=0
                    AND trx_hash='\xDEED'
                    AND ref_block_num=101
                    AND ref_block_prefix=100
                    AND expiration='2016-06-22 19:10:25-07'::timestamp
                    AND signature='\xBEEF'
                    AND fork_id = 1
    ) = 1, 'Wrong 1 transaction data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive_data.transactions_reversible
           WHERE
               block_num=101
           AND trx_in_block=1
           AND trx_hash='\xBEEF'
           AND ref_block_num=101
           AND ref_block_prefix=100
           AND expiration='2016-06-22 19:10:25-07'::timestamp
           AND signature='\xDEED'
           AND fork_id = 1
    ) = 1, 'Wrong 2 transaction data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive_data.transactions_multisig_reversible
            WHERE trx_hash = '\xDEED' AND signature = '\xFEED' AND fork_id = 1
    ) = 1, 'Wrong data of signature 1'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive_data.transactions_multisig_reversible
         WHERE trx_hash = '\xBEEF' AND signature = '\xBABE' AND fork_id = 1
             ) = 1, 'Wrong data of signature 2'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive_data.operations_reversible
        WHERE
                  id = hive.operation_id(101,1,0)
              AND trx_in_block = 0
              AND op_pos = 0
              AND body_binary = '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hive_data.operation
              AND fork_id = 1
    ) = 1, 'Wrong data of operation 1';

    ASSERT ( SELECT COUNT(*) FROM hive_data.operations_reversible
         WHERE
               id = hive.operation_id(101,2,0)
           AND trx_in_block = 1
           AND op_pos = 0
           AND body_binary = '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hive_data.operation
           AND fork_id = 1
     ) = 1, 'Wrong data of operation 2';

    ASSERT ( SELECT COUNT(*) FROM hive_data.accounts_reversible
        WHERE id = 1
        AND name = 'alice'
        AND block_num = 101
        AND fork_id = 1
    ) = 1, 'No alice account';

    ASSERT ( SELECT COUNT(*) FROM hive_data.accounts_reversible
         WHERE id = 2
         AND name = 'bob'
         AND block_num = 101
         AND fork_id = 1
    ) = 1, 'No bob account';

    ASSERT ( SELECT COUNT(*) FROM hive_data.account_operations_reversible
        WHERE account_id = 1
        AND account_op_seq_no = 1
        AND operation_id = hive.operation_id(101,1,0)
        AND fork_id = 1
    ) = 1 ,'No alice operation';

    ASSERT ( SELECT COUNT(*) FROM hive_data.account_operations_reversible
        WHERE account_id = 2
        AND account_op_seq_no = 1
        AND operation_id = hive.operation_id(101,2,0)
        AND fork_id = 1
    ) = 1 ,'No bob operation';

    ASSERT ( SELECT COUNT(*) FROM hive_data.applied_hardforks_reversible
        WHERE hardfork_num = 1
        AND block_num = 101
        AND hardfork_vop_id = 1
        AND fork_id = 1
    ) = 1, 'Wrong data of hardfork 1';

    ASSERT ( SELECT COUNT(*) FROM hive_data.applied_hardforks_reversible
        WHERE hardfork_num = 2
        AND block_num = 101
        AND hardfork_vop_id = 2
        AND fork_id = 1
    ) = 1, 'Wrong data of hardfork 2';


    ASSERT( SELECT is_dirty FROM hive_data.irreversible_data ) = FALSE, 'Irreversible data are dirty';
END
$BODY$
;




