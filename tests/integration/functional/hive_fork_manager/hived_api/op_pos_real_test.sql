
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a' );

    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hafd.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF', NULL )
         , ( 1, 1::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF', NULL )
    ;

    -- Virtual operations ( OP 3 ) are interleaved with the real ones and one of them is emitted
    -- outside of any transaction - they all have NULL op_pos_real, while the real operations
    -- are counted again after each of them ( compare op_pos with op_pos_real ).
    INSERT INTO hafd.operations( id, trx_in_block, op_type_id, op_pos, body_value, op_pos_real )
    VALUES
           ( hafd.operation_id(1, 0), 0, 1, 0, '{"message":"REAL 1"}'::jsonb, 0 )
         , ( hafd.operation_id(1, 1), 0, 1, 1, '{"message":"REAL 2"}'::jsonb, 1 )
         , ( hafd.operation_id(1, 2), 0, 3, 2, '{"message":"VIRTUAL 1"}'::jsonb, NULL )
         , ( hafd.operation_id(1, 3), 0, 1, 3, '{"message":"REAL 3"}'::jsonb, 2 )
         , ( hafd.operation_id(1, 4), 1, 1, 0, '{"message":"REAL 4"}'::jsonb, 0 )
         , ( hafd.operation_id(1, 5), -1, 3, 0, '{"message":"VIRTUAL 2"}'::jsonb, NULL )
    ;

    INSERT INTO hafd.blocks_reversible
    VALUES
        ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 1 )
    ;

    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_type_id, op_pos, body_value, op_pos_real, fork_id)
    VALUES
           ( hafd.operation_id(2, 0), 0, 1, 0, '{"message":"REAL 5"}'::jsonb, 0, 1 )
         , ( hafd.operation_id(2, 1), 0, 3, 1, '{"message":"VIRTUAL 3"}'::jsonb, NULL, 1 )
         , ( hafd.operation_id(2, 2), 0, 1, 2, '{"message":"REAL 6"}'::jsonb, 1, 1 )
    ;

    UPDATE hafd.hive_state SET consistent_block = 1;
    UPDATE hafd.contexts SET fork_id = 1, irreversible_block = 1, current_block_num = 2;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- make the reversible block irreversible and check that op_pos_real is copied along
    PERFORM hive.copy_operations_to_irreversible( 1, 2 );
    UPDATE hafd.hive_state SET consistent_block = 2;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TEMP TABLE expected( id BIGINT, op_pos INTEGER, op_pos_real INTEGER );
    INSERT INTO expected
    VALUES
           ( hafd.operation_id(1, 0), 0, 0 )
         , ( hafd.operation_id(1, 1), 1, 1 )
         , ( hafd.operation_id(1, 2), 2, NULL )
         , ( hafd.operation_id(1, 3), 3, 2 )
         , ( hafd.operation_id(1, 4), 0, 0 )
         , ( hafd.operation_id(1, 5), 0, NULL )
         , ( hafd.operation_id(2, 0), 0, 0 )
         , ( hafd.operation_id(2, 1), 1, NULL )
         , ( hafd.operation_id(2, 2), 2, 1 )
    ;

    ASSERT NOT EXISTS (
        SELECT id, op_pos, op_pos_real FROM hafd.operations
        EXCEPT SELECT * FROM expected
    ) , 'Unexpected rows in hafd.operations';
    ASSERT NOT EXISTS (
        SELECT * FROM expected
        EXCEPT SELECT id, op_pos, op_pos_real FROM hafd.operations
    ) , 'Missing rows in hafd.operations';

    ASSERT NOT EXISTS (
        SELECT id, op_pos, op_pos_real FROM hive.operations_view
        EXCEPT SELECT * FROM expected
    ) , 'Unexpected rows in hive.operations_view';
    ASSERT NOT EXISTS (
        SELECT * FROM expected
        EXCEPT SELECT id, op_pos, op_pos_real FROM hive.operations_view
    ) , 'Missing rows in hive.operations_view';

    ASSERT NOT EXISTS (
        SELECT id, op_pos, op_pos_real FROM hive.operations_view_extended
        EXCEPT SELECT * FROM expected
    ) , 'Unexpected rows in hive.operations_view_extended';
    ASSERT NOT EXISTS (
        SELECT * FROM expected
        EXCEPT SELECT id, op_pos, op_pos_real FROM hive.operations_view_extended
    ) , 'Missing rows in hive.operations_view_extended';

    ASSERT NOT EXISTS (
        SELECT id, op_pos, op_pos_real FROM hive.irreversible_operations_view
        EXCEPT SELECT * FROM expected
    ) , 'Unexpected rows in hive.irreversible_operations_view';
    ASSERT NOT EXISTS (
        SELECT * FROM expected
        EXCEPT SELECT id, op_pos, op_pos_real FROM hive.irreversible_operations_view
    ) , 'Missing rows in hive.irreversible_operations_view';

    ASSERT NOT EXISTS (
        SELECT id, op_pos, op_pos_real FROM a.operations_view
        EXCEPT SELECT * FROM expected
    ) , 'Unexpected rows in a.operations_view';
    ASSERT NOT EXISTS (
        SELECT * FROM expected
        EXCEPT SELECT id, op_pos, op_pos_real FROM a.operations_view
    ) , 'Missing rows in a.operations_view';

    ASSERT NOT EXISTS (
        SELECT id, op_pos, op_pos_real FROM a.operations_view_extended
        EXCEPT SELECT * FROM expected
    ) , 'Unexpected rows in a.operations_view_extended';
    ASSERT NOT EXISTS (
        SELECT * FROM expected
        EXCEPT SELECT id, op_pos, op_pos_real FROM a.operations_view_extended
    ) , 'Missing rows in a.operations_view_extended';

    ASSERT NOT EXISTS (
        SELECT FROM hive.operations_view ov
        JOIN hafd.operation_types ot ON ot.id = ov.op_type_id
        WHERE ot.is_virtual AND ov.op_pos_real IS NOT NULL
    ) , 'Virtual operations must have NULL op_pos_real';

    ASSERT NOT EXISTS (
        SELECT FROM hive.operations_view ov
        JOIN hafd.operation_types ot ON ot.id = ov.op_type_id
        WHERE NOT ot.is_virtual AND ov.op_pos_real IS NULL
    ) , 'Real operations must have a defined op_pos_real';
END;
$BODY$
;
