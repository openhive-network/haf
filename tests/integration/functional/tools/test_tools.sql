CREATE SCHEMA IF NOT EXISTS test;
GRANT CREATE ON SCHEMA test TO PUBLIC;
GRANT ALL ON SCHEMA test TO PUBLIC;


SELECT hive.initialize_extension_data();

CREATE OR REPLACE FUNCTION test.unordered_arrays_equal(arr1 TEXT[], arr2 TEXT[])
RETURNS bool
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
    return (arr1 <@ arr2 and arr1 @> arr2);
END
$$
;

CREATE PROCEDURE test.check_eq(a anyelement, b anyelement, msg text DEFAULT 'Expected to be equal, but failed')
LANGUAGE plpgsql
AS
$BODY$
BEGIN
  IF a <> b THEN
    assert (SELECT FALSE), FORMAT(E'%s:\na: %s\nb: %s', msg, a, b);
  END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION test.fill_with_blocks_data()
    RETURNS VOID
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
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
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( block_num, name, id )
    VALUES
    ( 1, 'u1', 1 )
         , ( 2, 'u2', 2 )
         , ( 3, 'u3', 3 )
         , ( 4, 'u4', 4 )
         , ( 5, 'u5', 5 )
    ;

    INSERT INTO hafd.transactions
    VALUES
    ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.transactions_multisig
    VALUES
    ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
         , ( '\xDEED30', '\xBAAD30' )
         , ( '\xDEED40', '\xBAAD40' )
         , ( '\xDEED50', '\xBAAD50' )
    ;

    INSERT INTO hafd.operations
    VALUES
    ( hafd.operation_id(1, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"ZERO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(2, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"ONE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(3, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"TWO OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(4, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation )
         , ( hafd.operation_id(5, 0), 0, 1, 0, '{"type":"system_warning_operation","value":{"message":"FIVE OPERATION"}}' :: jsonb :: hafd.operation )
    ;

    INSERT INTO hafd.account_operations(account_id, transacting_account_id, account_op_seq_no, operation_id, op_type_id)
    VALUES
           ( 1, 1, 1, hafd.operation_id(1, 0) , 1)
         , ( 1, 1, 2, hafd.operation_id(2, 0) , 1)
         , ( 2, 2, 1, hafd.operation_id(2, 0) , 1)
         , ( 3, 3, 1, hafd.operation_id(3, 0) , 1)
         , ( 4, 4, 1, hafd.operation_id(4, 0) , 1)
    ;

    INSERT INTO hafd.applied_hardforks
    VALUES
    ( 1, 1, hafd.operation_id(1, 0) )
         , ( 2, 2, hafd.operation_id(2, 0) )
         , ( 3, 3, hafd.operation_id(3, 0) )
         , ( 4, 4, hafd.operation_id(4, 0) )
         , ( 5, 5, hafd.operation_id(5, 0) )
    ;

    UPDATE hafd.contexts SET irreversible_block = 5, current_block_num = 5;

    UPDATE hafd.hive_state
    SET consistent_block = 5;
END;
$BODY$
;

