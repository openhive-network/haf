
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
          ( 1, 'hive::protocol::account_create_operation', FALSE )
    	, ( 2, 'hive::protocol::account_update_operation', FALSE)
        , ( 3, 'hive::protocol::recover_account_operation', FALSE)
        , ( 4, 'hive::protocol::request_account_recovery_operation', FALSE)
        , ( 7, 'hive::protocol::witness_set_properties_operation', FALSE)
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
                        "account_auths": [["ecency.app", 1], ["good-karma", 1]],
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
            '::jsonb::hive.operation ) 

        -- three keys from one owner
            , ( 2, 2, 0, 0, 2, '2016-06-22 19:10:21-07'::timestamp, '
                {
                    "type": "account_update_operation",
                    "value": {
                        "account": "recursive",
                        "owner": {
                            "weight_threshold": 1,
                            "account_auths": [["steemconnect", 1]],
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
                        "active": {
                            "weight_threshold": 1,
                            "account_auths": [["steemconne02", 1]],
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
            '::jsonb::hive.operation)

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
            '::jsonb::hive.operation )

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
            '::jsonb::hive.operation )
            , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_update_operation","value":{"account":"recursive","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",1],["STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx",1],["STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR",1]]},"memo_key":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","json_metadata":""}}' :: jsonb :: hive.operation )
            
            -- witness_set_properties_operation
            , ( 7, 5, 0, 1, 7, '2016-06-22 19:10:21-07'::timestamp,  
            '
            {
                "type": "witness_set_properties_operation",
                "value": {
                    "owner": "holger80",
                    "props": [
                        [
                            "account_creation_fee",
                            "b80b00000000000003535445454d0000"
                        ],
                        [
                            "key",
                            "0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"
                        ]
                    ],
                    "extensions": []
                }
            }'::jsonb::hive.operation)
            , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"other"}}' :: jsonb :: hive.operation )
        ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'KEYAUTH', 'context' );
    PERFORM hive.app_context_detach( 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 6;

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.update_state_provider_keyauth( 1, 5, 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    RAISE NOTICE 'TEST hive.context_keyauth TABLE contents: %', (E'\n' || (SELECT (json_agg(t)) FROM (SELECT * from hive.context_keyauth)t));

        -- one key from owner, one from active, one from posting, also in posting we have array of account_auths
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[1] = 'STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh' )), 'first of the keys in one key from owner, one from active, one from posting not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[1] = 'STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG' )), 'second of the keys in one key from owner, one from active, one from posting not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[1] = 'STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9' )), 'third of the keys in one key from owner, one from active, one from posting not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE account_name = 'andresricou' AND key_kind = 'POSTING' AND account_auth = ARRAY['ecency.app', 'good-karma'] ), 'Specified account and authority kind not found with the ecency.app, good-karma account_auth values';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE account_name = 'andresricou' AND key_kind = 'MEMO' AND key_auth = ARRAY ['STM6XUnQxSzLpUM6FMnuTTyG9LNXvzYbzW2J6qGH5sRTsQvCnGePo']), 'memo key not found';

        -- three keys from one owner, also a single account_auth value in owner (overriden in block 5) , also a single  account_auth value in active
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[1] = 'STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB' )), 'first of the three keys from one owner not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[2] = 'STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx' )), 'second of the three keys from one owner not found';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[3] = 'STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR' ) ),'third of the three keys from one owner not found';
    ASSERT NOT EXISTS ( SELECT * FROM hive.context_keyauth WHERE account_name = 'recursive' AND key_kind = 'OWNER' AND account_auth = ARRAY['steemconnect'] ), 'Specified account and authority kind should not found with the steemconnect account_auth value';
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE account_name = 'recursive' AND key_kind = 'ACTIVE' AND account_auth = ARRAY['steemconne02'] ), 'Specified account and authority kind not found with the steemconne02 account_auth value';

        -- recover_account_operation -- gathering only new_owner_authority, not recent_owner_authority
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[1] = 'STM5vp6ivg5iDZF4TmEJcQfW4ZV9849nqNbAQKMBNT7C4QiTzvMhm' ) ),'new_owner_authority in recover_account_operation not found';
    ASSERT NOT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[1] = 'STM6NX8as7FqVfpJFCvuTbhSicXdzMidXyif3q7rCrVooGLEs3AuY' ) ),'recent_owner_authority in recover_account_operation not found';

       -- request_account_recovery_operation -- we are not gathering it at all
    ASSERT NOT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_auth[1] = 'STM7aytvJLLEYy7L337pedpGaSg9TFE4mXbmKGUydVcBW3JrV6msz' ) ),'new_owner_authority in request_account_recovery_operation not found';

       -- witness_set_properties_operation
    ASSERT EXISTS ( SELECT * FROM hive.context_keyauth WHERE (key_kind = 'WITNESS_SIGNING' AND key_auth[1] = 'STM62PZocuByZa6645ERCLJmmqG7k97eB1Y9bRzQXDFPsjyUxGqVV' ) ),'witness_set_properties_operation key not correct';

       --overall key count
    ASSERT ( SELECT COUNT(*) FROM hive.context_keyauth ) = 11, 'Wrong number of current keys' || ' Should be 11 actual is ' ||  (SELECT COUNT(*) FROM hive.context_keyauth)::text;

        --check overall operations used
    ASSERT hive.unordered_arrays_equal(
        (SELECT array_agg(t.get_keyauths_operations) FROM hive.get_keyauths_operations()t),
        (SELECT array_agg(t) FROM hive.get_keyauths_operations_pattern()t)
    ), 'hive.get_keyauths_operations are not equal to the pattern';


    PERFORM hive.app_state_provider_drop( 'KEYAUTH', 'context' );

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
UNION ALL SELECT 'hive::protocol::reset_account_operation'
UNION ALL SELECT 'hive::protocol::witness_set_properties_operation'
;
END
$$;

