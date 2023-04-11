DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
          ( 1, 'hive::protocol::account_create_operation', FALSE )
    	, ( 2, 'hive::protocol::account_update_operation', FALSE)
        , ( 3, 'hive::protocol::recover_account_operation', FALSE)
        , ( 4, 'hive::protocol::request_account_recovery_operation', FALSE)
        , ( 6, 'other', FALSE ) -- non containing keys
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
        -- one key from owner, one from active, one from posting
          ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_create_operation",
                "value": {
                    "fee": {
                        "amount": "10000",
                        "precision": 3,
                        "nai": "@@000000021"
                    },
                    "creator": "steem",
                    "new_account_name": "andresricou",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM6XUnQxSzLpUM6FMnuTTyG9LNXvzYbzW2J6qGH5sRTsQvCnGePo",
                    "json_metadata": ""
                }
            }
            
            ' ) 

        -- three keys from one owner
            , ( 2, 2, 0, 0, 2, '2016-06-22 19:10:21-07'::timestamp, '
            
                {
                    "type": "account_update_operation",
                    "value": {
                        "account": "recursive",
                        "owner": {
                            "weight_threshold": 1,
                            "account_auths": [],
                            "key_auths": [
                                [
                                    "STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",
                                    1
                                ],
                                [
                                    "STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx",
                                    1
                                ],
                                [
                                    "STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR",
                                    1
                                ]
                            ]
                        },
                        "memo_key": "STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",
                        "json_metadata": ""
                    }
                }
            ') 
        
        -- recover_account_operation
            , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '
                {
                    "type": "recover_account_operation",
                    "value": {
                        "account_to_recover": "jcalfee",
                        "new_owner_authority": {
                            "weight_threshold": 1,
                            "account_auths": [],
                            "key_auths": [
                                [
                                    "STM5vp6ivg5iDZF4TmEJcQfW4ZV9849nqNbAQKMBNT7C4QiTzvMhm",
                                    1
                                ]
                            ]
                        },
                        "recent_owner_authority": {
                            "weight_threshold": 1,
                            "account_auths": [],
                            "key_auths": [
                                [
                                    "STM6NX8as7FqVfpJFCvuTbhSicXdzMidXyif3q7rCrVooGLEs3AuY",
                                    1
                                ]
                            ]
                        },
                        "extensions": []
                    }
                }            
            ' )

            -- request_account_recovery_operation
            , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '
                {
                    "type": "request_account_recovery_operation",
                    "value": {
                        "recovery_account": "steem",
                        "account_to_recover": "aiko",
                        "new_owner_authority": {
                            "weight_threshold": 1,
                            "account_auths": [],
                            "key_auths": [
                                [
                                    "STM7aytvJLLEYy7L337pedpGaSg9TFE4mXbmKGUydVcBW3JrV6msz",
                                    1
                                ]
                            ]
                        },
                        "extensions": []
                    }
                }
            ' )
            , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_update_operation","value":{"account":"recursive","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",1],["STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx",1],["STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR",1]]},"memo_key":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","json_metadata":""}}' )
            , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"other"}}' )
        ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'KEYAUTH', 'context' );
    PERFORM hive.app_context_detach( 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 6;

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
    PERFORM hive.update_state_provider_keyauth( 1, 5, 'context' );
END;
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
        -- one key from owner, one from active, one from posting
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh' )), 'first of the keys in one key from owner, one from active, one from posting not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG' )), 'second of the keys in one key from owner, one from active, one from posting not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9' )), 'third of the keys in one key from owner, one from active, one from posting not found';

        -- three keys from one owner
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB' )), 'first of the three keys from one owner not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx' )), 'second of the three keys from one owner not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR' ) ),'third of the three keys from one owner not found';

        -- recover_account_operation
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM5vp6ivg5iDZF4TmEJcQfW4ZV9849nqNbAQKMBNT7C4QiTzvMhm' ) ),'new_owner_authority in recover_account_operation not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM6NX8as7FqVfpJFCvuTbhSicXdzMidXyif3q7rCrVooGLEs3AuY' ) ),'recent_owner_authority in recover_account_operation not found';

       -- request_account_recovery_operation
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth = 'STM7aytvJLLEYy7L337pedpGaSg9TFE4mXbmKGUydVcBW3JrV6msz' ) ),'new_owner_authority in request_account_recovery_operation not found';

        --overall key count
    ASSERT ( SELECT COUNT(*) FROM hive.context_keyauth ) = 9, 'Wrong number of keys';

        --check overall operations used
    ASSERT hive.unordered_arrays_equal(
        (SELECT array_agg(t.get_keyauths_operations) FROM hive.get_keyauths_operations()t),
        (SELECT array_agg(t) FROM hive.get_keyauths_operations_pattern()t)
    ), 'Broken hive.get_keyauths_operations';

END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_keyauths_operations_pattern()
RETURNS SETOF TEXT
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
RETURN QUERY
          SELECT 'hive::protocol::account_create_operation'
UNION ALL SELECT 'hive::protocol::account_create_with_delegation_operation'
UNION ALL SELECT 'hive::protocol::account_update_operation'
UNION ALL SELECT 'hive::protocol::account_update2_operation'
UNION ALL SELECT 'hive::protocol::create_claimed_account_operation'
UNION ALL SELECT 'hive::protocol::recover_account_operation'
UNION ALL SELECT 'hive::protocol::request_account_recovery_operation'
UNION ALL SELECT 'hive::protocol::reset_account_operation'
UNION ALL SELECT 'hive::protocol::witness_set_properties_operation'
;
END
$$;

