-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create custom operation types for this test
    INSERT INTO hafd.operation_types
    VALUES
    ( 1, 'hive::protocol::account_created_operation', TRUE )
         , ( 6, 'other', FALSE ) -- non creating accounts
    ;

    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    -- Create initminer account
    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));

    INSERT INTO hafd.transactions
    VALUES
        ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_type_id, op_pos, body_binary, id)
    VALUES
        ( hafd.make_block_id(5, 0), 0, 0, 0, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_5","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hafd.operation, hafd.operation_id(5, 1) );

    PERFORM hive.end_massive_sync(5);

    -- live sync
    PERFORM hive.push_block(
                   ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.push_block(
                   ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.set_irreversible( 6 );

    PERFORM hive.push_block(
                   ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    INSERT INTO hafd.transactions
    VALUES
        ( hafd.make_block_id(8, 1), 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_type_id, op_pos, body_binary, id)
    VALUES
        ( hafd.make_block_id(8, 1), 0, 0, 0, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_8_rev","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 1) );


    PERFORM hive.push_block(
                   ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.back_from_fork( 7 );

    PERFORM hive.push_block(
                   ( 8, '\xBADD81', '\xCAFE81', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    INSERT INTO hafd.transactions
    VALUES
        ( hafd.make_block_id(8, 2), 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_type_id, op_pos, body_binary, id)
    VALUES
        ( hafd.make_block_id(8, 2), 0, 0, 0, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_8","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 1) );

    PERFORM hive.push_block(
                   ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.back_from_fork( 8 );

    PERFORM hive.push_block(
                   ( 9, '\xBADD92', '\xCAFE92', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.push_block(
                   ( 10, '\xBADD1010', '\xCAFE1010', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context('context', _schema => 'a', _is_forking => FALSE);
    PERFORM hive.app_next_block('context'); -- (1,6)
    PERFORM hive.app_context_detach('context');
    PERFORM hive.app_set_current_block_num('context', 6);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( 'context', 6 );
    CALL hive.appproc_context_attach('context');
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'NULL must be returned since there are no irreversible blocks grater tha 6';
END
$BODY$
;