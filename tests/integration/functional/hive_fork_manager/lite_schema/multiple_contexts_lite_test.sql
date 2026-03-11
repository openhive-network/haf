
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

CREATE OR REPLACE PROCEDURE alice_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create two independent app contexts in separate schemas
    CREATE SCHEMA app1;
    PERFORM hive.context_create( 'ctx_app1', 'app1' );
    CREATE TABLE app1.data1(id SERIAL PRIMARY KEY, val TEXT) INHERITS( app1.ctx_app1 );

    CREATE SCHEMA app2;
    PERFORM hive.context_create( 'ctx_app2', 'app2' );
    CREATE TABLE app2.data2(id SERIAL PRIMARY KEY, val TEXT) INHERITS( app2.ctx_app2 );
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
    -- Push a block so contexts have data to process
    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 1, '\x4007', E'[]', '\x2157',
                'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    __transaction = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
    __operation = ( hafd.operation_id(101, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"TEST"}}' :: jsonb :: hafd.operation, NULL );
    __signatures = ( '\xDEED', '\xFEED' );
    __account = ( 1, 'alice', 101 );
    __account_operation = ( 1, 1, 1, hafd.operation_id(101, 0), 1 );
    __applied_hardforks = (1, 101, hafd.operation_id(101, 0));
    PERFORM hive.push_block(
          __block
        , ARRAY[ __transaction ]
        , ARRAY[ __signatures ]
        , ARRAY[ __operation ]
        , ARRAY[ __account ]
        , ARRAY[ __account_operation ]
        , ARRAY[ __applied_hardforks ]
    );

    PERFORM hive.end_massive_sync( 101 );
    PERFORM hive.set_irreversible( 101 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Both contexts should exist independently
    ASSERT ( SELECT COUNT(*) FROM hafd.contexts WHERE name IN ('ctx_app1', 'ctx_app2') ) = 2,
        'Expected 2 contexts';

    -- Both registered tables should exist
    ASSERT EXISTS (SELECT FROM hafd.registered_tables WHERE origin_table_schema='app1' AND origin_table_name='data1'),
        'app1.data1 should be registered';
    ASSERT EXISTS (SELECT FROM hafd.registered_tables WHERE origin_table_schema='app2' AND origin_table_name='data2'),
        'app2.data2 should be registered';

    -- Neither should have shadow tables (lite schema)
    ASSERT NOT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name LIKE 'shadow%'),
        'No shadow tables should exist in lite schema';

    -- Verify block data is accessible
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks WHERE num = 101 ) = 1, 'Block 101 should exist';
END;
$BODY$
;
