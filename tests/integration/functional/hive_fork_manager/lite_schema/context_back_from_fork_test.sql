
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hafd.blocks%ROWTYPE;
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
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
    CREATE SCHEMA a;
    PERFORM hive.context_create( 'ctx', 'a' );
    CREATE TABLE a.t1(id SERIAL PRIMARY KEY DEFERRABLE, val TEXT) INHERITS( a.ctx );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block hafd.blocks%ROWTYPE;
BEGIN
    -- Insert a producer account first (needed for FK on blocks.producer_account_id in lite mode)
    -- Push two blocks
    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    PERFORM hive.push_block(
          __block
        , ARRAY[]::hafd.transactions[]
        , ARRAY[]::hafd.transactions_multisig[]
        , ARRAY[]::hafd.operations[]
        , ARRAY[ ROW(1, 'producer', 101)::hafd.accounts ]
        , ARRAY[]::hafd.account_operations[]
        , ARRAY[]::hafd.applied_hardforks[]
    );

    __block = ( 102, '\xBADE', '\xBADD', '2016-06-22 19:10:26-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    PERFORM hive.push_block(
          __block
        , ARRAY[]::hafd.transactions[]
        , ARRAY[]::hafd.transactions_multisig[]
        , ARRAY[]::hafd.operations[]
        , ARRAY[]::hafd.accounts[]
        , ARRAY[]::hafd.account_operations[]
        , ARRAY[]::hafd.applied_hardforks[]
    );

    -- Simulate app processing up to block 102
    UPDATE hafd.contexts SET current_block_num = 102 WHERE name = 'ctx';

    -- Insert some data into the app table
    INSERT INTO a.t1(val) VALUES ('data_at_block_101');
    INSERT INTO a.t1(val) VALUES ('data_at_block_102');

    -- Now rewind to block 101 (fork)
    PERFORM hive.context_back_from_fork( 'ctx', 101 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Context block num should be rewound
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'ctx' ) = 101, 'Context block num not rewound';

    -- In lite mode, app table data is NOT reverted (no shadow tables to revert from)
    -- Both rows should still be there
    ASSERT ( SELECT COUNT(*) FROM a.t1 ) = 2, 'App table data should be unchanged in lite mode (no shadow table rewind)';
END;
$BODY$
;
