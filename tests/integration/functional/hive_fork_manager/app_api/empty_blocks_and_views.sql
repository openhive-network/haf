DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    CREATE TABLE table1( id INT ) INHERITS( hive.context );

    INSERT INTO hive.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hive.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.operations
    VALUES
    ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: hive.operation )
    ;

    INSERT INTO hive.transactions_multisig
    VALUES
           ( '\xDEED10', '\xBAAD10' )
    ;


    INSERT INTO hive.blocks_reversible
    VALUES
           ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 2 )
         , ( 2, '\xBADD23', '\xCAFE23', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000, 3 )
    ;

    -- block 2 on fork 3 has no transactions
    INSERT INTO hive.transactions_reversible
    VALUES
           ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF', 2 )
    ;

    -- block 2 on fork 3 has no signatures
    INSERT INTO hive.transactions_multisig_reversible
    VALUES ( '\xDEED20', '\xBAAD20', 2 )
    ;

    -- block 2 on fork 3 has no operations
    INSERT INTO hive.operations_reversible
    VALUES
        ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: hive.operation, 2 )
    ;

    UPDATE hive.contexts SET fork_id = 3, irreversible_block = 1, current_block_num = 2;
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    --NOTHING TODO HERE
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_operations_view' ), 'No context transactions view';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.context_operations_view
        EXCEPT SELECT * FROM ( VALUES
              ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: hive.operation )
        ) as pattern
    ) , 'Unexpected rows in the operations view';


    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
              ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: hive.operation )
        ) as pattern
        EXCEPT SELECT * FROM hive.context_operations_view
    ) , 'Unexpected rows in the operations view2';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.context_transactions_view
        EXCEPT SELECT * FROM ( VALUES
              ( 1, 0::SMALLINT, '\xDEED10'::bytea, 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF'::bytea )
        ) as pattern
    ) , 'Unexpected rows in the transacations view';


    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
              ( 1, 0::SMALLINT, '\xDEED10'::bytea, 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF'::bytea )
        ) as pattern
        EXCEPT SELECT * FROM hive.context_transactions_view
    ) , 'Unexpected rows in the transacations view2';

    ASSERT NOT EXISTS (
        SELECT * FROM hive.context_transactions_multisig_view
        EXCEPT SELECT * FROM ( VALUES
             ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
        ) as pattern
    ) , 'Unexpected rows in the transacations sig view';


    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
              ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
        ) as pattern
        EXCEPT SELECT * FROM hive.context_transactions_multisig_view
    ) , 'Unexpected rows in the transacations sig view2';
END;
$BODY$
;




