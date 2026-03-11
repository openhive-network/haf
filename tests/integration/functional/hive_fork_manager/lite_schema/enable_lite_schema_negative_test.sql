
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
    ;

    -- Connect in full mode first
    PERFORM hive.connect( 'test_full', 0, 0, 0, FALSE, FALSE );

    -- Push a block to get data in the DB
    PERFORM hive.push_block(
          ( 1, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )::hafd.blocks
        , ARRAY[]::hafd.transactions[]
        , ARRAY[]::hafd.transactions_multisig[]
        , ARRAY[]::hafd.operations[]
        , ARRAY[]::hafd.accounts[]
        , ARRAY[]::hafd.account_operations[]
        , ARRAY[]::hafd.applied_hardforks[]
    );
    PERFORM hive.end_massive_sync( 1 );
    PERFORM hive.set_irreversible( 1 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Should fail: cannot enable lite schema on DB with existing blocks
    PERFORM hive.connect( 'test_lite', 1, 1, 0, TRUE, TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT hive.is_lite_schema(), 'lite_schema flag should not be set';
    ASSERT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='blocks_reversible'), 'blocks_reversible should still exist';
    ASSERT EXISTS (SELECT FROM information_schema.tables WHERE table_schema='hafd' AND table_name='fork'), 'fork table should still exist';
END;
$BODY$
;
