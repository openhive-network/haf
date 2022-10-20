--SELECT pg_terminate_backend(pg_stat_activity.pid)
--FROM pg_stat_activity
--WHERE pg_stat_activity.datname = 'psql_tools_test_db'
--  AND pid <> pg_backend_pid();
--
--CREATE DATABASE 'psql_tools_test_db';
--
--CREATE EXTENSION hive_fork_manager CASCADE;



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
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"andrewy","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7yHyxuXUjkxPq8gFLXKdMsSzG3BZ8TRLMntXwhGtxh8e6dUiz7",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5SF1d7gfivQV5qeSW4Q2QZKjmb7VijYA8B2JTTeoBcLsNJGGvJ",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6dhhNXms1U8NRdyjy7fvp58Lp93k29tXwXCsmidpqLhQShcspb",1]]},"memo_key":"STM8PwzScFzga3q7fufrKKXb63UiXAop9HAMfNi3dL8VdeVhvUgwt","json_metadata":""}}' ) 
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"anelysian","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5Nk6sXTTXkvhbBqN8TqwFHrLFsFVhtmTgTb89ZkCK2iYAwYViF",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5eiYtwxtmAvFN9DpGVUfEAB4dofgxDigxjQehfXpGym8dH2hXr",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5fQibw7LbBakH9v78CGazB8BhDxc2f9X8Nt9YiqHFQMRrDKgXk",1]]},"memo_key":"STM8GAhHsReV48RRJ9JkkFBbbxBJ8MX3jaxUayBj9xZfNQhCAQ2S9","json_metadata":""}}' )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"ani-ana","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM883Dpz3x7pTqm9kWb1GX6tFeJ5VsydgHLNcoKRyNLawnD5JBo5",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7BvbiWaUXC5yEgnSmFAkVXFRtaN24udnqSCWQXFtB1bcvDboJR",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5fmDL9xjobxr7KLufkKWR27LiagjpATJv5DTnyM7XwSQCyrAVg",1]]},"memo_key":"STM7pLCGTGJqDt3fKkM1upabWpmJR86yvaLii3jX6gnKv1n9z2rzh","json_metadata":""}}' )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"bellissima","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8d6bHYCvC623pm6tBbyFbaus5pCQCFBySroPGZF9p3aRL1RE9D",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8KGXpCV5vAQ9e7knaoSwky5yzupFDPssEPkVDQHDjs8QxnSSqN",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM838ZbAmNKeajhpvxBxz9jqEShxPbuknFfXH1MEShT5AKzR11u7",1]]},"memo_key":"STM4y4TSLY2WexnrqcvamafhB7J7rkNYvA8ueuDWHwrNf9KgJRBnK","json_metadata":""}}' )
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
    PERFORM hive.start_provider_accounts( 'context' );
    UPDATE hive.contexts SET current_block_num = 6, irreversible_block = 6;

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
    PERFORM hive.update_state_provider_accounts( 1, 5, 'context' );
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
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow' ), 'account_from_pow not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow2' ), 'account_from_pow2 not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_account' ), 'account_from_create_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account' ), 'account_from_create_claimed_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account_del' ), 'account_create_with_delegation_operation not created';

    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts';
END;
$BODY$
;





SELECT test_given();
SELECT test_when();
SELECT test_then();

--SELECT pg_terminate_backend(pg_stat_activity.pid)
--FROM pg_stat_activity
--WHERE pg_stat_activity.datname = 'psql_tools_test_db'
--  AND pid <> pg_backend_pid();
--
--CREATE DATABASE 'psql_tools_test_db';
--
--CREATE EXTENSION hive_fork_manager CASCADE;



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
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"andrewy","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7yHyxuXUjkxPq8gFLXKdMsSzG3BZ8TRLMntXwhGtxh8e6dUiz7",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5SF1d7gfivQV5qeSW4Q2QZKjmb7VijYA8B2JTTeoBcLsNJGGvJ",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6dhhNXms1U8NRdyjy7fvp58Lp93k29tXwXCsmidpqLhQShcspb",1]]},"memo_key":"STM8PwzScFzga3q7fufrKKXb63UiXAop9HAMfNi3dL8VdeVhvUgwt","json_metadata":""}}' ) 
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"anelysian","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5Nk6sXTTXkvhbBqN8TqwFHrLFsFVhtmTgTb89ZkCK2iYAwYViF",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5eiYtwxtmAvFN9DpGVUfEAB4dofgxDigxjQehfXpGym8dH2hXr",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5fQibw7LbBakH9v78CGazB8BhDxc2f9X8Nt9YiqHFQMRrDKgXk",1]]},"memo_key":"STM8GAhHsReV48RRJ9JkkFBbbxBJ8MX3jaxUayBj9xZfNQhCAQ2S9","json_metadata":""}}' )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"ani-ana","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM883Dpz3x7pTqm9kWb1GX6tFeJ5VsydgHLNcoKRyNLawnD5JBo5",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7BvbiWaUXC5yEgnSmFAkVXFRtaN24udnqSCWQXFtB1bcvDboJR",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5fmDL9xjobxr7KLufkKWR27LiagjpATJv5DTnyM7XwSQCyrAVg",1]]},"memo_key":"STM7pLCGTGJqDt3fKkM1upabWpmJR86yvaLii3jX6gnKv1n9z2rzh","json_metadata":""}}' )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"creator":"steem","new_account_name":"bellissima","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8d6bHYCvC623pm6tBbyFbaus5pCQCFBySroPGZF9p3aRL1RE9D",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8KGXpCV5vAQ9e7knaoSwky5yzupFDPssEPkVDQHDjs8QxnSSqN",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM838ZbAmNKeajhpvxBxz9jqEShxPbuknFfXH1MEShT5AKzR11u7",1]]},"memo_key":"STM4y4TSLY2WexnrqcvamafhB7J7rkNYvA8ueuDWHwrNf9KgJRBnK","json_metadata":""}}' )
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
    PERFORM hive.start_provider_accounts( 'context' );
    UPDATE hive.contexts SET current_block_num = 6, irreversible_block = 6;

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
    PERFORM hive.update_state_provider_accounts( 1, 5, 'context' );
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
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow' ), 'account_from_pow not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow2' ), 'account_from_pow2 not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_account' ), 'account_from_create_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account' ), 'account_from_create_claimed_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account_del' ), 'account_create_with_delegation_operation not created';

    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts';
END;
$BODY$
;





SELECT test_given();
SELECT test_when();
SELECT test_then();


