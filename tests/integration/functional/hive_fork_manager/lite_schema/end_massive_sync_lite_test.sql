
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
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
    -- Push 3 blocks, then end_massive_sync and set_irreversible
    FOR i IN 101..103 LOOP
        __block = ( i, decode('BA' || lpad(to_hex(i), 4, '0'), 'hex'), decode('CA' || lpad(to_hex(i-1), 4, '0'), 'hex'),
                    ('2016-06-22 19:10:25-07'::timestamp + (i * interval '3 seconds')), i - 100, '\x4007', E'[]', '\x2157',
                    'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
        __transaction = ( i, 0::SMALLINT, decode('DE' || lpad(to_hex(i), 4, '0'), 'hex'), i, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
        __operation = ( hafd.operation_id(i, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"BLOCK"}}' :: jsonb :: hafd.operation, NULL );
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

    PERFORM hive.end_massive_sync( 103 );
    PERFORM hive.set_irreversible( 103 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- All blocks should be in irreversible tables after end_massive_sync + set_irreversible
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE num BETWEEN 101 AND 103 ) = 3,
        'Expected 3 blocks after end_massive_sync';

    -- Global views should work
    ASSERT ( SELECT COUNT(*) FROM hive.blocks_view WHERE num BETWEEN 101 AND 103 ) = 3,
        'blocks_view should show 3 blocks';

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_view WHERE block_num BETWEEN 101 AND 103 ) = 3,
        'transactions_view should show 3 transactions';

    ASSERT ( SELECT COUNT(*) FROM hive.operations_view WHERE hafd.operation_id_to_block_num(id) BETWEEN 101 AND 103 ) = 3,
        'operations_view should show 3 operations';

    -- Events queue should have entries
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue ) > 0,
        'Events queue should have entries after end_massive_sync';
END;
$BODY$
;
