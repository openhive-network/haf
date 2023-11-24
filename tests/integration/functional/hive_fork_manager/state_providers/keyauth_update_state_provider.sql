




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
         , ( 6, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 7, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 8, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1),
    (6, 'test-safari', 1),
    (7, 'howo', 1),
    (8, 'andresricou', 1),
    (9, 'spscontest', 1),
    (10, 'recursive', 1),
    (11, 'sloth.buzz', 1),
    (12, 'simple-app', 1),
    (13, 'jcalfee', 1),
    (14, 'margemnlpz08', 1),
    (15, 'holger80', 1),
    (16, 'jte1023', 1),
    (17, 'adedayoolumide', 1),
    (18, 'eos-polska', 1),
    (19, 'ecency.app', 1),
    (20, 'good-karma', 1),
    (21, 'steemconnect', 1),
    (22, 'steemconne02', 1)
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
            , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp,
            '
                {
                    "type": "account_update_operation",
                    "value": {
                        "account": "recursive",
                        "owner": {
                            "weight_threshold": 1,
                            "account_auths": [],
                            "key_auths": [
                                [
                                    "STM7TN7SNuvMM6Zha6NKTZP7q6f4BmC1UXnAJxb2vjMfE89gep3HZ",
                                    1
                                ],
                                [
                                    "STM87WL3HWWwA1qYy4Qywp9WMWUNL8txGHTAJZdEU8Rs9h6vZH3B5",
                                    1
                                ],
                                [
                                    "STM7YSZmysv6xxKApsCqgZ8Xuact1Bsnfuvv299B3cWye8FYakDri",
                                    1
                                ]
                            ]
                        },
                        "memo_key": "STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",
                        "json_metadata": ""
                    }
                }            ' :: jsonb :: hive.operation )

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

            , ( 8, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp,
            '
                {
                    "type": "account_update_operation",
                    "value": {
                        "account": "recursive",
                        "owner": {
                            "weight_threshold": 1,
                            "account_auths": [["steemconne02", 1]],
                            "key_auths": [
                                [
                                    "STM82hFUKjN2j8KGqQ8rz9YgFAbMrWFuCPkabtrAnUfV2JQshNPLz",
                                    1
                                ],
                                [
                                    "STM4zCuP6xBTdCBZjyg9eMSku3wDnBaAX6o9uNCXwFafzqTC5tm5j",
                                    1
                                ],
                                [
                                    "STM6ZVzWQvbYSzVpY2PRJHu7QSASVy8aB8xSVcJgx5seYGHPFvJkZ",
                                    1
                                ],
                                [
                                    "STM78LtxupZ8YcTXthdY13SSymguhGyPrnSPLdJTkUFGogJ9JqTRa",
                                    1
                                ]
                            ]
                        },
                        "memo_key": "STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB",
                        "json_metadata": ""
                    }
                }            ' :: jsonb :: hive.operation )


        ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'KEYAUTH', 'context' );
    PERFORM hive.app_context_detach( 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 8;

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
DECLARE
    result TEXT;
BEGIN


    CREATE VIEW keyauth_view AS
    SELECT 
            a.*
        ,   k.key
        ,  acc.name
    FROM hive.context_keyauth_a a
    JOIN hive.context_keyauth_k k ON a.key_serial_id = k.key_id
    JOIN hive.accounts acc ON acc.id = account_id
    ;

    PERFORM hive.print_recordset_with_label('Whole resulting keyauth_view', 'SELECT * FROM keyauth_view');

        -- one key from owner, one from active, one from posting, also in posting we have array of account_auths
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh' )), 'first of the keys in one key from owner, one from active, one from posting not found';
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG' )), 'second of the keys in one key from owner, one from active, one from posting not found';
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9' )), 'third of the keys in one key from owner, one from active, one from posting not found';

        -- three keys from one owner, also a single account_auth value in owner (overriden in block 5) , also a single  account_auth value in active
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB' )), 'first of the three keys from one owner not found';
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx' )), 'second of the three keys from one owner not found';
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR' ) ),'third of the three keys from one owner not found';

        -- recover_account_operation -- gathering only new_owner_authority, not recent_owner_authority
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM5vp6ivg5iDZF4TmEJcQfW4ZV9849nqNbAQKMBNT7C4QiTzvMhm' ) ),'new_owner_authority in recover_account_operation not found';
    ASSERT NOT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM6NX8as7FqVfpJFCvuTbhSicXdzMidXyif3q7rCrVooGLEs3AuY' ) ),'recent_owner_authority in recover_account_operation not found';

       -- request_account_recovery_operation -- we are not gathering it at all
    ASSERT NOT EXISTS ( SELECT * FROM keyauth_view WHERE (hive.public_key_to_string(key) = 'STM7aytvJLLEYy7L337pedpGaSg9TFE4mXbmKGUydVcBW3JrV6msz' ) ),'new_owner_authority in request_account_recovery_operation not found';

       -- witness_set_properties_operation
    ASSERT EXISTS ( SELECT * FROM keyauth_view WHERE (key_kind = 'WITNESS_SIGNING' AND hive.public_key_to_string(key) = 'STM62PZocuByZa6645ERCLJmmqG7k97eB1Y9bRzQXDFPsjyUxGqVV' ) ),'witness_set_properties_operation key not correct';

       --overall key count
    ASSERT ( SELECT COUNT(*) FROM hive.context_keyauth_a ) = 13, 'Wrong number of current keys' || ' Should be 13 actual is ' ||  (SELECT COUNT(*) FROM hive.context_keyauth_a)::text;

        --check overall operations used
    ASSERT hive.unordered_arrays_equal(
        (SELECT array_agg(t.get_keyauths_operations) FROM hive.get_keyauths_operations()t),
        (SELECT array_agg(t) FROM hive.get_keyauths_operations_pattern()t)
    ), 'hive.get_keyauths_operations are not equal to the pattern';

        -- check the whole key table

    PERFORM compare_keyauth_data('[
                {"public_key_to_string":"STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh","key_id":1,"account_id":8, "name":"andresricou", "key_kind":"OWNER","key_serial_id":1,"weight_threshold":1,"w":1,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","hive_rowid":1,"key":"\\x03932efa0867801610654c5d27621347cf5d2aeea8bdbf8bf9762c57d48f5e6f4b"}, 
                {"public_key_to_string":"STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG","key_id":2,"account_id":8,"name":"andresricou","key_kind":"ACTIVE","key_serial_id":2,"weight_threshold":1,"w":1,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","hive_rowid":2,"key":"\\x0205dbbc7c34d17cc2ded972e4527841d922ade2fdea5edab77272dfb01252abf6"}, 
                {"public_key_to_string":"STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9","key_id":3,"account_id":8,"name":"andresricou","key_kind":"POSTING","key_serial_id":3,"weight_threshold":1,"w":1,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","hive_rowid":3,"key":"\\x02ba95a2604262ee0c53ecb2bb44eb5422032f9c5d5f5460dd512fa16672962ac8"}, 
                {"public_key_to_string":"STM6XUnQxSzLpUM6FMnuTTyG9LNXvzYbzW2J6qGH5sRTsQvCnGePo","key_id":4,"account_id":8,"name":"andresricou","key_kind":"MEMO","key_serial_id":4,"weight_threshold":0,"w":0,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","hive_rowid":4,"key":"\\x02d7afd2fcdaf526b69d1a4489766b96511534b90180f1fd4a19d69ba43054823c"}, 
                {"public_key_to_string":"STM62PZocuByZa6645ERCLJmmqG7k97eB1Y9bRzQXDFPsjyUxGqVV","key_id":5,"account_id":15,"name":"holger80","key_kind":"WITNESS_SIGNING","key_serial_id":5,"weight_threshold":1,"w":1,"op_serial_id":7,"block_num":5,"timestamp":"2016-06-22T19:10:21","hive_rowid":5,"key":"\\x0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"}, 
                {"public_key_to_string":"STM5vp6ivg5iDZF4TmEJcQfW4ZV9849nqNbAQKMBNT7C4QiTzvMhm","key_id":6,"account_id":13,"name":"jcalfee","key_kind":"OWNER","key_serial_id":6,"weight_threshold":1,"w":1,"op_serial_id":3,"block_num":3,"timestamp":"2016-06-22T19:10:21","hive_rowid":6,"key":"\\x0288f8a188036e2de2b7683f5419c0c597acd1d89df22e23fa196bd6b3ab00e70f"}, 
                {"public_key_to_string":"STM7TN7SNuvMM6Zha6NKTZP7q6f4BmC1UXnAJxb2vjMfE89gep3HZ","key_id":7,"account_id":10,"name":"recursive","key_kind":"OWNER","key_serial_id":7,"weight_threshold":1,"w":1,"op_serial_id":5,"block_num":5,"timestamp":"2016-06-22T19:10:21","hive_rowid":7,"key":"\\x03520a0a4c3e3da618919b7f54b366503b27991e87d997fd80ca9301059f34bf52"}, 
                {"public_key_to_string":"STM7YSZmysv6xxKApsCqgZ8Xuact1Bsnfuvv299B3cWye8FYakDri","key_id":8,"account_id":10,"name":"recursive","key_kind":"OWNER","key_serial_id":8,"weight_threshold":1,"w":1,"op_serial_id":5,"block_num":5,"timestamp":"2016-06-22T19:10:21","hive_rowid":8,"key":"\\x035d91137a851cc4a15e3b3ae2ac35da5653b95fa85bbc2c8af1647fb5a2c9c06a"}, 
                {"public_key_to_string":"STM87WL3HWWwA1qYy4Qywp9WMWUNL8txGHTAJZdEU8Rs9h6vZH3B5","key_id":9,"account_id":10,"name":"recursive","key_kind":"OWNER","key_serial_id":9,"weight_threshold":1,"w":1,"op_serial_id":5,"block_num":5,"timestamp":"2016-06-22T19:10:21","hive_rowid":9,"key":"\\x03a8a5021d86ff107280b51d9cec9adee16d9fce7c57f749f3e3dfd17de8001c76"}, 
                {"public_key_to_string":"STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx","key_id":10,"account_id":10,"name":"recursive","key_kind":"ACTIVE","key_serial_id":10,"weight_threshold":1,"w":1,"op_serial_id":2,"block_num":2,"timestamp":"2016-06-22T19:10:21","hive_rowid":10,"key":"\\x023032d7738563754599177e8c25aa5dc873047d493c677c3dbdf39720d9412bb9"}, 
                {"public_key_to_string":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","key_id":11,"account_id":10,"name":"recursive","key_kind":"MEMO","key_serial_id":11,"weight_threshold":0,"w":0,"op_serial_id":5,"block_num":5,"timestamp":"2016-06-22T19:10:21","hive_rowid":11,"key":"\\x0209b6ff66b3f04d5b38a93171f180eba1f38bb807adb5ffe144181aa301d6190d"}, 
                {"public_key_to_string":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","key_id":11,"account_id":10,"name":"recursive","key_kind":"ACTIVE","key_serial_id":11,"weight_threshold":1,"w":1,"op_serial_id":2,"block_num":2,"timestamp":"2016-06-22T19:10:21","hive_rowid":12,"key":"\\x0209b6ff66b3f04d5b38a93171f180eba1f38bb807adb5ffe144181aa301d6190d"}, 
                {"public_key_to_string":"STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR","key_id":12,"account_id":10,"name":"recursive","key_kind":"ACTIVE","key_serial_id":12,"weight_threshold":1,"w":1,"op_serial_id":2,"block_num":2,"timestamp":"2016-06-22T19:10:21","hive_rowid":13,"key":"\\x0389d28937022880a7f0c7deaa6f46b4d87ce08bd5149335cb39b5a8e9b04981c2"}
                ]');



    CREATE VIEW account_auth_view AS SELECT
        account_id
        , accounts_view.name account_name
        , key_kind
        , account_auth_id
        , av.name as account_supervisor_name
        , weight_threshold
        , w
        , context_accountauth_a.block_num
        , op_serial_id
        , timestamp
        FROM hive.context_accountauth_a
        JOIN hive.accounts_view accounts_view ON accounts_view.id = context_accountauth_a.account_id
        JOIN hive.accounts_view av ON av.id = context_accountauth_a.account_auth_id
    ;


    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'andresricou' AND 
        key_kind = 'POSTING' AND 
        account_supervisor_name = 'ecency.app' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 1 AND 
        block_num = 1 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 8 AND 
        account_auth_id = 19
    ), 'ecency.app not ok';

    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'andresricou' AND 
        key_kind = 'POSTING' AND 
        account_supervisor_name = 'good-karma' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 1 AND 
        block_num = 1 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 8 AND 
        account_auth_id = 20
    ), 'good-karma not ok';

    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'recursive' AND 
        key_kind = 'OWNER' AND 
        account_supervisor_name = 'steemconnect' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 2 AND 
        block_num = 2 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 10 AND 
        account_auth_id = 21
    ), 'steemconnect OWNER not ok';

    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'recursive' AND 
        key_kind = 'ACTIVE' AND 
        account_supervisor_name = 'steemconne02' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 2 AND 
        block_num = 2 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 10 AND 
        account_auth_id = 22
    ), 'steemconne02 ACTIVE not ok';


-- RUN THE ENGINE the second time for block 6
    PERFORM hive.update_state_provider_keyauth( 6, 6, 'context' );


    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'andresricou' AND 
        key_kind = 'POSTING' AND 
        account_supervisor_name = 'ecency.app' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 1 AND 
        block_num = 1 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 8 AND 
        account_auth_id = 19
    ), 'Assertion failed: ecency.app authorization for andresricou not found.';

    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'andresricou' AND 
        key_kind = 'POSTING' AND 
        account_supervisor_name = 'good-karma' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 1 AND 
        block_num = 1 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 8 AND 
        account_auth_id = 20
    ), 'Assertion failed: good-karma authorization for andresricou not found.';

    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'recursive' AND 
        key_kind = 'OWNER' AND 
        account_supervisor_name = 'steemconne02' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 8 AND 
        block_num = 6 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 10 AND 
        account_auth_id = 22
    ), 'Assertion failed: steemconne02 OWNER authorization for recursive not found.';

    ASSERT EXISTS (
        SELECT * FROM account_auth_view WHERE 
        account_name = 'recursive' AND 
        key_kind = 'ACTIVE' AND 
        account_supervisor_name = 'steemconne02' AND 
        weight_threshold = 1 AND 
        w = 1 AND 
        op_serial_id = 2 AND 
        block_num = 2 AND 
        timestamp = '2016-06-22T19:10:21' AND 
        account_id = 10 AND 
        account_auth_id = 22
    ), 'Assertion failed: steemconne02 ACTIVE authorization for recursive not found.';

    PERFORM compare_keyauth_data(
            '[
                {"public_key_to_string":"STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG","key_id":2,"account_id":8,"name":"andresricou","key_kind":"ACTIVE","key_serial_id":2,"weight_threshold":1,"w":1,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","hive_rowid":2,"key":"\\x0205dbbc7c34d17cc2ded972e4527841d922ade2fdea5edab77272dfb01252abf6"}, 
                 {"public_key_to_string":"STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9","key_id":3,"account_id":8,"name":"andresricou","key_kind":"POSTING","key_serial_id":3,"weight_threshold":1,"w":1,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","hive_rowid":3,"key":"\\x02ba95a2604262ee0c53ecb2bb44eb5422032f9c5d5f5460dd512fa16672962ac8"}, 
                 {"public_key_to_string":"STM62PZocuByZa6645ERCLJmmqG7k97eB1Y9bRzQXDFPsjyUxGqVV","key_id":5,"account_id":15,"name":"holger80","key_kind":"WITNESS_SIGNING","key_serial_id":5,"weight_threshold":1,"w":1,"op_serial_id":7,"block_num":5,"timestamp":"2016-06-22T19:10:21","hive_rowid":5,"key":"\\x0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"}, 
                 {"public_key_to_string":"STM5FiXEtrfGsgv2jFoQqVCBkbeVRxrGxhHmjRJX4wEH3n36FkrBx","key_id":10,"account_id":10,"name":"recursive","key_kind":"ACTIVE","key_serial_id":10,"weight_threshold":1,"w":1,"op_serial_id":2,"block_num":2,"timestamp":"2016-06-22T19:10:21","hive_rowid":10,"key":"\\x023032d7738563754599177e8c25aa5dc873047d493c677c3dbdf39720d9412bb9"}, 
                 {"public_key_to_string":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","key_id":11,"account_id":10,"name":"recursive","key_kind":"ACTIVE","key_serial_id":11,"weight_threshold":1,"w":1,"op_serial_id":2,"block_num":2,"timestamp":"2016-06-22T19:10:21","hive_rowid":12,"key":"\\x0209b6ff66b3f04d5b38a93171f180eba1f38bb807adb5ffe144181aa301d6190d"}, 
                 {"public_key_to_string":"STM7sw22HqsXbz7D2CmJfmMwt9rimtk518dRzsR1f8Cgw52dQR1pR","key_id":12,"account_id":10,"name":"recursive","key_kind":"ACTIVE","key_serial_id":12,"weight_threshold":1,"w":1,"op_serial_id":2,"block_num":2,"timestamp":"2016-06-22T19:10:21","hive_rowid":13,"key":"\\x0389d28937022880a7f0c7deaa6f46b4d87ce08bd5149335cb39b5a8e9b04981c2"}, 
                 {"public_key_to_string":"STM4zCuP6xBTdCBZjyg9eMSku3wDnBaAX6o9uNCXwFafzqTC5tm5j","key_id":14,"account_id":10,"name":"recursive","key_kind":"OWNER","key_serial_id":14,"weight_threshold":1,"w":1,"op_serial_id":8,"block_num":6,"timestamp":"2016-06-22T19:10:21","hive_rowid":14,"key":"\\x020cfad0e91739b640c8d2b6b69373978e1e27efe67f60a234f37c3a4bed6d1646"}, 
                 {"public_key_to_string":"STM6ZVzWQvbYSzVpY2PRJHu7QSASVy8aB8xSVcJgx5seYGHPFvJkZ","key_id":15,"account_id":10,"name":"recursive","key_kind":"OWNER","key_serial_id":15,"weight_threshold":1,"w":1,"op_serial_id":8,"block_num":6,"timestamp":"2016-06-22T19:10:21","hive_rowid":15,"key":"\\x02dc467ea138c65fbbe51e19062bd5e350b6b16a3fc68b46df2775360050728770"}, 
                 {"public_key_to_string":"STM78LtxupZ8YcTXthdY13SSymguhGyPrnSPLdJTkUFGogJ9JqTRa","key_id":16,"account_id":10,"name":"recursive","key_kind":"OWNER","key_serial_id":16,"weight_threshold":1,"w":1,"op_serial_id":8,"block_num":6,"timestamp":"2016-06-22T19:10:21","hive_rowid":16,"key":"\\x0326d98e47b17df753ec4ba949224a1c8e5e755ebd3916b56cb929719507cb42f0"}, 
                 {"public_key_to_string":"STM82hFUKjN2j8KGqQ8rz9YgFAbMrWFuCPkabtrAnUfV2JQshNPLz","key_id":17,"account_id":10,"name":"recursive","key_kind":"OWNER","key_serial_id":17,"weight_threshold":1,"w":1,"op_serial_id":8,"block_num":6,"timestamp":"2016-06-22T19:10:21","hive_rowid":17,"key":"\\x039db8109f3cbd64f9aef68bd08406346d6116d98f757fa9e4953efb884d0b6252"}, 
                 {"public_key_to_string":"STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh","account_id":8,"name":"andresricou","key_kind":"OWNER","weight_threshold":1,"w":1,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","key":"\\x03932efa0867801610654c5d27621347cf5d2aeea8bdbf8bf9762c57d48f5e6f4b"}, 
                 {"public_key_to_string":"STM6XUnQxSzLpUM6FMnuTTyG9LNXvzYbzW2J6qGH5sRTsQvCnGePo","account_id":8,"name":"andresricou","key_kind":"MEMO","weight_threshold":0,"w":0,"op_serial_id":1,"block_num":1,"timestamp":"2016-06-22T19:10:21","key":"\\x02d7afd2fcdaf526b69d1a4489766b96511534b90180f1fd4a19d69ba43054823c"}, 
                 {"public_key_to_string":"STM4xmWJcNo2UyJMbWZ6cjVpi4NYuL1ViyPrPgmqCDMKdckkeagEB","account_id":10,"name":"recursive","key_kind":"MEMO","weight_threshold":0,"w":0,"op_serial_id":8,"block_num":6,"timestamp":"2016-06-22T19:10:21","key":"\\x0209b6ff66b3f04d5b38a93171f180eba1f38bb807adb5ffe144181aa301d6190d"}, 
                 {"public_key_to_string":"STM5vp6ivg5iDZF4TmEJcQfW4ZV9849nqNbAQKMBNT7C4QiTzvMhm","account_id":13,"name":"jcalfee","key_kind":"OWNER","weight_threshold":1,"w":1,"op_serial_id":3,"block_num":3,"timestamp":"2016-06-22T19:10:21","key":"\\x0288f8a188036e2de2b7683f5419c0c597acd1d89df22e23fa196bd6b3ab00e70f"}
                ]');

    DROP VIEW keyauth_view;
    DROP VIEW account_auth_view;

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
UNION ALL SELECT 'hive::protocol::pow_operation'
UNION ALL SELECT 'hive::protocol::pow2_operation'
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



CREATE OR REPLACE FUNCTION compare_keyauth_data(expected_json_text TEXT)
RETURNS VOID AS $$
DECLARE
    result TEXT;
BEGIN

    CREATE TEMP TABLE expected_table AS SELECT
            (elem->>'public_key_to_string')::TEXT AS public_key_to_string,
            (elem->>'account_id')::INTEGER AS account_id,
            (elem->>'name')::TEXT AS name,
            (elem->>'key_kind')::hive.key_type AS key_kind,
            (elem->>'key_id')::INTEGER AS key_auth_key_serial,
            (elem->>'weight_threshold')::INTEGER AS weight_threshold,
            (elem->>'w')::INTEGER AS w,
            (elem->>'op_serial_id')::BIGINT AS op_serial_id,
            (elem->>'block_num')::INTEGER AS block_num,
            (elem->>'timestamp')::TIMESTAMP AS timestamp,
            (elem->>'hive_rowid')::INTEGER AS hive_rowid,
            (elem->>'key_id')::INTEGER AS key_id,
            (elem->>'key')::BYTEA AS key 
        FROM (
            SELECT json_array_elements(expected_json_text
                ::json) AS elem
            ) t;


    WITH json_data AS (SELECT * FROM expected_table)
    SELECT
        CASE WHEN count(*) = 0 AND (SELECT count(*) FROM keyauth_view) = (SELECT count(*) FROM json_data)
            THEN 'Equal'
            ELSE 'Not Equal'
        END INTO result
    FROM (
        SELECT
            hive.public_key_to_string(key),
            account_id, name, key_kind, weight_threshold, w, op_serial_id, block_num, timestamp,
            key
        FROM keyauth_view

        EXCEPT

        SELECT
            public_key_to_string,
            account_id, name, key_kind, weight_threshold, w, op_serial_id, block_num, timestamp,
            key
    FROM json_data
    ) AS differences;


    PERFORM hive.compare_recordsets(

        'SELECT
            public_key_to_string,
            account_id, name, key_kind, weight_threshold, w, op_serial_id, block_num, timestamp,
            key
        FROM expected_table',

        'SELECT 
            hive.public_key_to_string(key),
            account_id, name, key_kind, weight_threshold, w, op_serial_id, block_num, timestamp,
            key
        FROM keyauth_view');

    DROP TABLE expected_table;


    ASSERT result = 'Equal', 'The table and JSON data are not equal.';



END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION hive.compare_recordsets(expected_text text, actual_text text) RETURNS void LANGUAGE plpgsql AS $BODY$
BEGIN

    PERFORM hive.print_recordset_with_label(
        'Common Rows', 
        'WITH expected AS (' || expected_text || '), actual AS (' || actual_text || ') ' ||
        'SELECT * FROM expected INTERSECT SELECT * FROM actual'
    );


    PERFORM hive.print_recordset_with_label(
        'Expected Only Rows',
        'WITH expected AS (' || expected_text || '), actual AS (' || actual_text || ') ' ||
        'SELECT * FROM expected EXCEPT SELECT * FROM actual'
    );


    PERFORM hive.print_recordset_with_label(
        'Actual Only Rows',
        'WITH expected AS (' || expected_text || '), actual AS (' || actual_text || ') ' ||
        'SELECT * FROM actual EXCEPT SELECT * FROM expected'
    );
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.print_recordset_with_label(label text, query_string text) RETURNS void LANGUAGE plpgsql AS $p$
DECLARE 
     json_result json;
BEGIN
    EXECUTE format('SELECT json_agg(t) FROM (%s) AS t', query_string) INTO json_result;
    RAISE NOTICE E'% >>>> \n%', label, json_result;
END;
$p$;
