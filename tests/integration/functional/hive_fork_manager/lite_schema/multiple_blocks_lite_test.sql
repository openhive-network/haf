
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
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
    __transaction hafd.transactions%ROWTYPE;
    __operation hafd.operations%ROWTYPE;
    __signatures hafd.transactions_multisig%ROWTYPE;
    __account hafd.accounts%ROWTYPE;
    __account_operation hafd.account_operations%ROWTYPE;
    __applied_hardforks hafd.applied_hardforks%ROWTYPE;
BEGIN
    -- Push 3 blocks sequentially to verify accumulation in irreversible tables
    FOR i IN 101..103 LOOP
        __block = ( i, decode('BA' || lpad(to_hex(i), 4, '0'), 'hex'), decode('CA' || lpad(to_hex(i-1), 4, '0'), 'hex'),
                    ('2016-06-22 19:10:25-07'::timestamp + (i * interval '3 seconds')), 5, '\x4007', E'[]', '\x2157',
                    'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
        __transaction = ( i, 0::SMALLINT, decode('DE' || lpad(to_hex(i), 4, '0'), 'hex'), i, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
        __operation = ( hafd.operation_id(i, 0), 0, 1, 0, ('{"type":"system_warning_operation","value":{"message":"BLOCK ' || i || '"}}') :: jsonb :: hafd.operation, NULL );
        __signatures = ( decode('DE' || lpad(to_hex(i), 4, '0'), 'hex'), '\xFEED' );
        __account = ( i - 100, 'user' || (i - 100), i );
        __account_operation = ( i - 100, i - 100, 1, hafd.operation_id(i, 0), 1 );
        __applied_hardforks = (i - 100, i, hafd.operation_id(i, 0));
        PERFORM hive.push_block(
              __block
            , ARRAY[ __transaction ]
            , ARRAY[ __signatures ]
            , ARRAY[ __operation ]
            , ARRAY[ __account ]
            , ARRAY[ __account_operation ]
            , ARRAY[ __applied_hardforks ]
        );
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- All 3 blocks should be in irreversible tables
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE num BETWEEN 101 AND 103 ) = 3,
        'Expected 3 blocks in irreversible table, got ' || ( SELECT COUNT(*) FROM hafd.blocks WHERE num BETWEEN 101 AND 103 );

    ASSERT ( SELECT COUNT(*) FROM hafd.transactions WHERE block_num BETWEEN 101 AND 103 ) = 3,
        'Expected 3 transactions in irreversible table';

    ASSERT ( SELECT COUNT(*) FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) BETWEEN 101 AND 103 ) = 3,
        'Expected 3 operations in irreversible table';

    ASSERT ( SELECT COUNT(*) FROM hafd.accounts WHERE block_num BETWEEN 101 AND 103 ) = 3,
        'Expected 3 accounts in irreversible table';

    -- Verify blocks are ordered correctly
    ASSERT ( SELECT num FROM hafd.blocks ORDER BY num DESC LIMIT 1 ) = 103,
        'Last block should be 103';
END;
$BODY$
;
