-- Test push_block function with unified table architecture
-- Verifies that pushing a block correctly inserts data into all unified tables
-- Note: push_block receives *_type composites with INTEGER block_num, not block_id
-- The function internally creates block_id from block_num and current fork
-- Load test utilities
\ir ../test_tools.sql


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
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    -- Use proper *_type composites (block_num INTEGER, not block_id)
    __block hafd.blocks_type;
    __transaction1 hafd.transactions_type;
    __transaction2 hafd.transactions_type;
    __operation1_1 hafd.operations_type;
    __operation2_1 hafd.operations_type;
    __signatures1 hafd.transactions_multisig_type;
    __signatures2 hafd.transactions_multisig_type;
    __account1 hafd.accounts_type;
    __account2 hafd.accounts_type;
    __account_operation1 hafd.account_operations_type;
    __account_operation2 hafd.account_operations_type;
    __applied_hardforks1 hafd.applied_hardforks_type;
    __applied_hardforks2 hafd.applied_hardforks_type;
BEGIN
    -- blocks_type: (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G' , 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );

    -- transactions_type: (block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature)
    __transaction1 = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
    __transaction2 = ( 101, 1::SMALLINT, '\xBEEF', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xDEED' );

    -- operations_type: (id, trx_in_block, op_pos, body_binary)
    __operation1_1 = ( hafd.operation_id(101,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation );
    __operation2_1 = ( hafd.operation_id(101,2,0), 1, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation );

    -- transactions_multisig_type: (trx_hash, signature)
    __signatures1 = ( '\xDEED', '\xFEED' );
    __signatures2 = ( '\xBEEF', '\xBABE' );

    -- accounts_type: (id, name, block_num)
    __account1 = ( 1, 'alice', 101 );
    __account2 = ( 2, 'bob', 101 );

    -- account_operations_type: (account_id, transacting_account_id, account_op_seq_no, operation_id)
    __account_operation1 = ( 1, 1, 1, hafd.operation_id(101,1,0) );
    __account_operation2 = ( 2, 1, 1, hafd.operation_id(101,2,0) );

    -- applied_hardforks_type: (hardfork_num, block_num, hardfork_vop_id)
    __applied_hardforks1 = (1, 101, hafd.operation_id(101,1,0));
    __applied_hardforks2 = (2, 101, hafd.operation_id(101,2,0));

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
DECLARE
    __block_id hafd.block_id;
BEGIN
    -- push_block creates block_id with fork 1 (first reversible fork)
    __block_id = hafd.make_block_id(101, 1);

    ASSERT EXISTS ( SELECT FROM hafd.events_queue WHERE id = 1 AND event = 'NEW_BLOCK' AND block_num = 101 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue ) = 3, 'Unexpected number of events';

    -- Check unified tables (no more *_reversible tables)
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE block_id = __block_id ) = 1, 'Unexpected number of blocks';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions WHERE block_id = __block_id ) = 2, 'Unexpected number of transactions';
    ASSERT ( SELECT COUNT(*) FROM hafd.transactions_multisig WHERE block_id = __block_id ) = 2, 'Unexpected number of signatures';
    ASSERT ( SELECT COUNT(*) FROM hafd.operations WHERE block_id = __block_id ) = 2, 'Unexpected number of operations';

    ASSERT  ( SELECT COUNT(*) FROM hafd.blocks
                    WHERE
                        block_id = __block_id
                    AND hash='\xBADD'
                    AND prev='\xCAFE'
                    AND created_at='2016-06-22 19:10:25-07'::timestamp
                    AND producer_account_id=5
    ) = 1, 'Wrong block data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hafd.transactions
                    WHERE
                        block_id = __block_id
                    AND trx_in_block=0
                    AND trx_hash='\xDEED'
                    AND ref_block_num=101
                    AND ref_block_prefix=100
                    AND expiration='2016-06-22 19:10:25-07'::timestamp
                    AND signature='\xBEEF'
    ) = 1, 'Wrong 1 transaction data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hafd.transactions
           WHERE
               block_id = __block_id
           AND trx_in_block=1
           AND trx_hash='\xBEEF'
           AND ref_block_num=101
           AND ref_block_prefix=100
           AND expiration='2016-06-22 19:10:25-07'::timestamp
           AND signature='\xDEED'
    ) = 1, 'Wrong 2 transaction data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hafd.transactions_multisig
            WHERE trx_hash = '\xDEED' AND signature = '\xFEED' AND block_id = __block_id
    ) = 1, 'Wrong data of signature 1'
    ;

    ASSERT ( SELECT COUNT(*) FROM hafd.transactions_multisig
         WHERE trx_hash = '\xBEEF' AND signature = '\xBABE' AND block_id = __block_id
             ) = 1, 'Wrong data of signature 2'
    ;

    ASSERT ( SELECT COUNT(*) FROM hafd.operations
        WHERE
                  id = hafd.operation_id(101,1,0)
              AND trx_in_block = 0
              AND op_pos = 0
              AND body_binary = '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation
              AND block_id = __block_id
    ) = 1, 'Wrong data of operation 1';

    ASSERT ( SELECT COUNT(*) FROM hafd.operations
         WHERE
               id = hafd.operation_id(101,2,0)
           AND trx_in_block = 1
           AND op_pos = 0
           AND body_binary = '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation
           AND block_id = __block_id
     ) = 1, 'Wrong data of operation 2';

    ASSERT ( SELECT COUNT(*) FROM hafd.accounts
        WHERE id = 1
        AND name = 'alice'
        AND block_id = __block_id
    ) = 1, 'No alice account';

    ASSERT ( SELECT COUNT(*) FROM hafd.accounts
         WHERE id = 2
         AND name = 'bob'
         AND block_id = __block_id
    ) = 1, 'No bob account';

    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations
        WHERE account_id = 1
        AND account_op_seq_no = 1
        AND block_id = __block_id
    ) = 1 ,'No alice operation';

    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations
        WHERE account_id = 2
        AND account_op_seq_no = 1
        AND block_id = __block_id
    ) = 1 ,'No bob operation';

    ASSERT ( SELECT COUNT(*) FROM hafd.applied_hardforks
        WHERE hardfork_num = 1
        AND block_id = __block_id
        AND hardfork_vop_id = hafd.operation_id(101,1,0)
    ) = 1, 'Wrong data of hardfork 1';

    ASSERT ( SELECT COUNT(*) FROM hafd.applied_hardforks
        WHERE hardfork_num = 2
        AND block_id = __block_id
        AND hardfork_vop_id = hafd.operation_id(101,2,0)
    ) = 1, 'Wrong data of hardfork 2';


    ASSERT( SELECT is_dirty FROM hafd.hive_state ) = FALSE, 'Irreversible data are dirty';
END
$BODY$
;
