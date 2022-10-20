DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
          ( 1, 'hive::protocol::account_create_operation', FALSE )
	, (2 ,'hive::protocol::account_update_operation', FALSE)
        , ( 6, 'other', FALSE ) -- non creating accounts
    ;

 
    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
     ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hive.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

   INSERT INTO hive.operations
    VALUES
          ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"andresricou","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9",1]]},"memo_key":"STM6XUnQxSzLpUM6FMnuTTyG9LNXvzYbzW2J6qGH5sRTsQvCnGePo","json_metadata":""}}' ) 
         , ( 2, 2, 0, 0, 2, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_update_operation","value":{"account":"recursive","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",1],["STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx",1],["STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR",1]]},"memo_key":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","json_metadata":""}}') 
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_update_operation","value":{"account":"recursive","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",1],["STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx",1],["STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR",1]]},"memo_key":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","json_metadata":""}}' )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_update_operation","value":{"account":"recursive","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",1],["STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx",1],["STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR",1]]},"memo_key":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","json_metadata":""}}' )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_update_operation","value":{"account":"recursive","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",1],["STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx",1],["STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR",1]]},"memo_key":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","json_metadata":""}}' )
         , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, 'other' )
    ;

    -- INSERT INTO hive.operations
    -- VALUES
    --        ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_pow"}}' ) --pow
    --      , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_pow2"}}' ) --pow2
    --      , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_create_account"}}' )
    --      , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_create_claimed_account"}}' )
    --      , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_create_claimed_account_del"}}' )
    --      , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, 'other' )
    -- ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'KEYAUTH', 'context' );
    PERFORM hive.app_context_detach( 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 6;

END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.update_state_provider_keyauth( 1, 5, 'context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE name = 'STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh' ), 'key STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE name = 'STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB' ), 'key STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB from update not found';
    -- ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE name = 'account_from_create_account' ), 'account_from_create_account not created';
    -- ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE name = 'account_from_create_claimed_account' ), 'account_from_create_claimed_account not created';
    -- ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE name = 'account_from_create_claimed_account_del' ), 'account_create_with_delegation_operation not created';

    -- ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts';
END;
$BODY$
;






