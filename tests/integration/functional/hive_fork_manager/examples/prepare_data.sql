START TRANSACTION;

INSERT INTO hive.operation_types
VALUES
       ( 1, 'hive::protocol::account_created_operation', TRUE )
     , ( 6, 'other', FALSE ) -- non creating accounts
;


INSERT INTO hive.blocks
VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
;

INSERT INTO hive.accounts( id, name, block_num )
VALUES
      ( 5, 'initminer', 1 )
;

INSERT INTO hive.transactions
VALUES
    ( 1, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
;

INSERT INTO hive.operations
VALUES
( 1, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_5"}}' );

INSERT INTO hive.applied_hardforks
VALUES
( 1, 5, 1 )
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

INSERT INTO hive.transactions_reversible
VALUES
    ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 1 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 2, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_8_reversible"}}', 1 );


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

INSERT INTO hive.transactions_reversible
VALUES
    ( 8, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 2 )
;

INSERT INTO hive.operations_reversible
VALUES
    ( 2, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_8"}}', 2 );

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
