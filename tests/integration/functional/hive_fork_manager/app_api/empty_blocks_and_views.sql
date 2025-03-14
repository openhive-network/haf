
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE table1( id INT ) INHERITS( a.context );

    INSERT INTO hafd.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hafd.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.operations
    VALUES
    ( hafd.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
    ;

    INSERT INTO hafd.transactions_multisig
    VALUES
           ( '\xDEED10', '\xBAAD10' )
    ;


    INSERT INTO hafd.blocks_reversible
    VALUES
           ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 2, '\xBADD23', '\xCAFE23', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    -- block 2 on fork 3 has no transactions
    INSERT INTO hafd.transactions_reversible
    VALUES
           ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF', 2 )
    ;

    -- block 2 on fork 3 has no signatures
    INSERT INTO hafd.transactions_multisig_reversible
    VALUES ( '\xDEED20', '\xBAAD20', 2 )
    ;

    -- block 2 on fork 3 has no operations
    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
    VALUES
        ( hafd.operation_id(2, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation, 2 )
    ;

    UPDATE hafd.contexts SET fork_id = 3, irreversible_block = 1, current_block_num = 2;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='operations_view' ), 'No context operations view';

    ASSERT NOT EXISTS (
        SELECT o.id, o.trx_in_block, o.op_pos, o.body_binary, o.body FROM a.operations_view o
        EXCEPT SELECT * FROM ( VALUES
              ( hafd.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb )
        ) as pattern
    ) , 'Unexpected rows in the operations view';


    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
              ( hafd.operation_id(1, 1, 0), 0, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb )
        ) as pattern
        EXCEPT SELECT o.id, o.trx_in_block, o.op_pos, o.body_binary, o.body FROM a.operations_view o
    ) , 'Unexpected rows in the operations view2';

    ASSERT NOT EXISTS (
        SELECT * FROM a.transactions_view
        EXCEPT SELECT * FROM ( VALUES
              ( 1, 0::SMALLINT, '\xDEED10'::bytea, 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF'::bytea )
        ) as pattern
    ) , 'Unexpected rows in the transacations view';


    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
              ( 1, 0::SMALLINT, '\xDEED10'::bytea, 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF'::bytea )
        ) as pattern
        EXCEPT SELECT * FROM a.transactions_view
    ) , 'Unexpected rows in the transacations view2';

    ASSERT NOT EXISTS (
        SELECT * FROM a.transactions_multisig_view
        EXCEPT SELECT * FROM ( VALUES
             ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
        ) as pattern
    ) , 'Unexpected rows in the transacations sig view';


    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
              ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
        ) as pattern
        EXCEPT SELECT * FROM a.transactions_multisig_view
    ) , 'Unexpected rows in the transacations sig view2';
END;
$BODY$
;




