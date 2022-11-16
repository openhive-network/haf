DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;
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
DECLARE
    __block hive.blocks%ROWTYPE;
    __transaction1 hive.transactions%ROWTYPE;
    __transaction2 hive.transactions%ROWTYPE;
    __operation1_1 hive.operations%ROWTYPE;
    __operation2_1 hive.operations%ROWTYPE;
    __signatures1 hive.transactions_multisig%ROWTYPE;
    __signatures2 hive.transactions_multisig%ROWTYPE;
    __account1 hive.accounts%ROWTYPE;
    __account2 hive.accounts%ROWTYPE;
    __account_operation1 hive.account_operations%ROWTYPE;
    __account_operation2 hive.account_operations%ROWTYPE;
BEGIN
    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G' );
    __transaction1 = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
    __transaction2 = ( 101, 1::SMALLINT, '\xBEEF', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xDEED' );
    __operation1_1 = ( 1, 101, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ZERO OPERATION' );
    __operation2_1 = ( 2, 101, 1, 0, 2, '2016-06-22 19:10:21-07'::timestamp, 'ONE OPERATION' );
    __signatures1 = ( '\xDEED', '\xFEED' );
    __signatures2 = ( '\xBEEF', '\xBABE' );
    __account1 = ( 1, 'alice', 101 );
    __account2 = ( 2, 'bob', 101 );
    __account_operation1 = ( 101, 1, 1, 1, 1 );
    __account_operation2 = ( 102, 2, 1, 2, 2 );
    PERFORM hive.push_block(
          __block
        , ARRAY[ __transaction1, __transaction2 ]
        , ARRAY[ __signatures1, __signatures2 ]
        , ARRAY[ __operation1_1, __operation2_1 ]
        , ARRAY[ __account1, __account2 ]
        , ARRAY[ __account_operation1, __account_operation2 ]
    );
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


    ASSERT EXISTS ( SELECT FROM hive.events_queue WHERE id = 1 AND event = 'NEW_BLOCK' AND block_num = 101 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 2, 'Unexpected number of events';

    ASSERT ( SELECT COUNT(*) FROM hive.blocks_reversible ) = 1, 'Unexpected number of blocks';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_reversible ) = 2, 'Unexpected number of transactions';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig_reversible ) = 2, 'Unexpected number of signatures';
    ASSERT ( SELECT COUNT(*) FROM hive.operations_reversible ) = 2, 'Unexpected number of operations';

    ASSERT  ( SELECT COUNT(*) FROM hive.blocks_reversible
                    WHERE
                        num=101
                    AND hash='\xBADD'
                    AND prev='\xCAFE'
                    AND created_at='2016-06-22 19:10:25-07'::timestamp
                    AND producer_account_id=5
                    AND fork_id = 1
    ) = 1, 'Wrong block data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_reversible
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

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_reversible
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

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig_reversible
            WHERE trx_hash = '\xDEED' AND signature = '\xFEED' AND fork_id = 1
    ) = 1, 'Wrong data of signature 1'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig_reversible
         WHERE trx_hash = '\xBEEF' AND signature = '\xBABE' AND fork_id = 1
             ) = 1, 'Wrong data of signature 2'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.operations_reversible
        WHERE
                  id = 1
              AND block_num = 101
              AND trx_in_block = 0
              AND op_pos = 0
              AND op_type_id = 1
              AND timestamp = '2016-06-22 19:10:21-07'::timestamp
              AND body = 'ZERO OPERATION'
              AND fork_id = 1
    ) = 1, 'Wrong data of operation 1';

    ASSERT ( SELECT COUNT(*) FROM hive.operations_reversible
         WHERE
               id = 2
           AND block_num = 101
           AND trx_in_block = 1
           AND op_pos = 0
           AND op_type_id = 2
           AND timestamp = '2016-06-22 19:10:21-07'::timestamp
           AND body = 'ONE OPERATION'
           AND fork_id = 1
     ) = 1, 'Wrong data of operation 2';

    ASSERT ( SELECT COUNT(*) FROM hive.accounts_reversible
        WHERE id = 1
        AND name = 'alice'
        AND block_num = 101
        AND fork_id = 1
    ) = 1, 'No alice account';

    ASSERT ( SELECT COUNT(*) FROM hive.accounts_reversible
         WHERE id = 2
         AND name = 'bob'
         AND block_num = 101
         AND fork_id = 1
    ) = 1, 'No bob account';

    ASSERT ( SELECT COUNT(*) FROM hive.account_operations_reversible
        WHERE account_id = 1
        AND account_op_seq_no = 1
        AND operation_id = 1
        AND fork_id = 1
    ) = 1 ,'No alice operation';

    ASSERT ( SELECT COUNT(*) FROM hive.account_operations_reversible
        WHERE account_id = 2
        AND account_op_seq_no = 1
        AND operation_id = 2
        AND fork_id = 1
    ) = 1 ,'No bob operation';



    ASSERT coalesce((SELECT is_dirty FROM hive.get_irr_data()), FALSE) = FALSE, 'Irreversible data are dirty';

END
$BODY$
;




