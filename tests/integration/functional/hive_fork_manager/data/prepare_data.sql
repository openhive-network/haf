INSERT INTO hive.operation_types
VALUES
       ( 1, 'hive::protocol::account_created_operation', TRUE )
     , ( 6, 'other', FALSE ) -- non creating accounts
;


INSERT INTO hive.blocks
VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
     , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
;

INSERT INTO hive.transactions
VALUES
    ( 1, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
;

INSERT INTO hive.operations
VALUES
( 1, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_5"}}' );

SELECT hive.end_massive_sync(5);

-- live sync
SELECT hive.push_block(
         ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.push_block(
         ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.set_irreversible( 6 );

SELECT hive.push_block(
         ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

INSERT INTO hive.transactions_reversible
VALUES
    ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 1 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 2, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_8_reversible"}}', 1 );


SELECT hive.push_block(
         ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.back_from_fork( 7 );

SELECT hive.push_block(
         ( 8, '\xBADD81', '\xCAFE81', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

INSERT INTO hive.transactions_reversible
VALUES
    ( 8, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 2 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 2, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_8"}}', 2 );

SELECT hive.push_block(
         ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
);

SELECT hive.back_from_fork( 8 );

SELECT hive.push_block(
         ( 9, '\xBADD92', '\xCAFE92', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.push_block(
         ( 10, '\xBADD1010', '\xCAFE1010', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

SELECT hive.push_block(
         ( 11, '\xBADD101A', '\xCAFE101B', '2016-06-22 19:10:28-07'::timestamp )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

INSERT INTO hive.transactions_reversible
VALUES
    ( 11, 0::SMALLINT, '\xDEED71', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEE', 3 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 2, 11, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_created_operation","value":{"new_account_name":"alice_001","creator":"initminer","initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"}}}', 3 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 3, 11, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_created_operation","value":{"new_account_name":"alice_002","creator":"initminer","initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"}}}', 3 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 4, 11, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"transfer_operation","value":{"from":"initimner","to":"berniesanders","amount":{"amount":"12000","precision":3,"nai":"@@000000021"},"memo":"bittrex"}}', 3 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 5, 11, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"transfer_operation","value":{"from":"berniesanders","to":"gtg","amount":{"amount":"12000","precision":3,"nai":"@@000000021"},"memo":"this is sending from BITTREX"}}', 3 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 6, 11, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"witness_update_operation","value":{"owner":"ihashfury","url":"https://steemit.com/witness-category/@ihashfury/ihashfury-witness-thread","block_signing_key":"STM8aUs6SGoEmNYMd3bYjE1UBr6NQPxGWmTqTdBaxJYSx244edSB2","props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}', 3 )
;
