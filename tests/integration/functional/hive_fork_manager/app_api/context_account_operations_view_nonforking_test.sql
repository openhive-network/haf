
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context', _schema => 'a' );

    INSERT INTO hafd.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.blocks
    VALUES
        ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 100, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.operations
    VALUES
           ( hafd.operation_id(1, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(2, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(3, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(4, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(5, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
    ;

    INSERT INTO hafd.accounts
    VALUES
           ( 100, 'alice1', 1 )
         , ( 200, 'alice2', 2 )
         , ( 300, 'alice3', 3 )
         , ( 400, 'alice4', 4 )
    ;

    INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id)
    VALUES
           ( 100, 100, 1, hafd.operation_id(1, 0), 1)
         , ( 100, 100, 2, hafd.operation_id(2, 0), 1)
         , ( 200, 200, 1, hafd.operation_id(2, 0), 1)
         , ( 300, 300, 1, hafd.operation_id(3, 0), 1)
         , ( 400, 400, 1, hafd.operation_id(4, 0), 1)
    ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='account_operations_view' ), 'No context accounts operations view';

    ASSERT NOT EXISTS (
        SELECT * FROM a.account_operations_view
        EXCEPT SELECT * FROM ( VALUES
               ( 1, 100, 100, 1, hafd.operation_id(1, 0), 1 )
             , ( 2, 100, 100, 2, hafd.operation_id(2, 0), 1 )
             , ( 2, 200, 200, 1, hafd.operation_id(2, 0), 1 )
             , ( 3, 300, 300, 1, hafd.operation_id(3, 0), 1 )
             , ( 4, 400, 400, 1, hafd.operation_id(4, 0), 1 )
        ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT ( SELECT COUNT(*) FROM a.account_operations_view ) = 5, 'Not all rows are visible';

END
$BODY$
;

