START TRANSACTION;

SELECT test.install_mock_hive_get_estimated_hive_head_block();
SELECT test.set_head_block_num(6);

INSERT INTO hafd.operation_types
VALUES
       ( 1, 'hive::protocol::account_created_operation', TRUE )
     , ( 6, 'other', FALSE ) -- non creating accounts
;


INSERT INTO hafd.blocks
VALUES
       ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(3, 0), '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(4, 0), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( hafd.make_block_id(5, 0), '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
;

INSERT INTO hafd.accounts( id, name, block_id )
VALUES
      ( 5, 'initminer', hafd.make_block_id(1, 0) )
;

INSERT INTO hafd.transactions
VALUES
    ( hafd.make_block_id(5, 0), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
;

INSERT INTO hafd.operations(block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary, id)
VALUES
( hafd.make_block_id(5, 0), 0, 1, 0, 0, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_5","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hafd.operation, hafd.operation_id(5, 0, 1) );

INSERT INTO hafd.applied_hardforks(hardfork_num, block_id, hardfork_vop_id)
VALUES
( 1, hafd.make_block_id(5, 0), hafd.operation_id(5, 1, 0) )
;

SELECT hive.end_massive_sync(5);

-- live sync
SELECT hive.push_block(
         ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.push_block(
         ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.set_irreversible( 6 );

SELECT hive.push_block(
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

INSERT INTO hafd.operations(block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary, id)
VALUES
    ( hafd.make_block_id(8, 1), 0, 1, 0, 0, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_8_revers","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 0, 1) );


SELECT hive.push_block(
         ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.back_from_fork( 7 );

SELECT hive.push_block(
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

INSERT INTO hafd.operations(block_id, seq_in_block, op_type_id, trx_in_block, op_pos, body_binary, id)
VALUES
    ( hafd.make_block_id(8, 2), 0, 1, 0, 0, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_8","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hafd.operation, hafd.operation_id(8, 0, 1) );

SELECT hive.push_block(
         ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
);

SELECT hive.back_from_fork( 8 );

SELECT hive.push_block(
         ( 9, '\xBADD92', '\xCAFE92', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.push_block(
         ( 10, '\xBADD1010', '\xCAFE1010', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );


COMMIT;
