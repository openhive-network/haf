
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN

    INSERT INTO hive.operation_types
    VALUES
        ( 43, 'hive::protocol::account_update2_operation', FALSE ),
        ( 9, 'hive::protocol::account_create_operation', FALSE ),
        ( 41, 'hive::protocol::account_create_with_delegation_operation', FALSE ),
        ( 10, 'hive::protocol::account_update_operation', FALSE ),
        ( 23, 'hive::protocol::create_claimed_account_operation', FALSE )
         -- non containing keys
    ;
 
    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , (10, '\xBADDA0', '\xCAFEA0', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , (11, '\xBADDB0', '\xCAFEB0', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , (12, '\xBADDC0', '\xCAFEC0', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , (13, '\xBADDD0', '\xCAFED0', '2016-06-22 19:10:33-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , (14, '\xBADDD0', '\xCAFED0', '2016-06-22 19:10:33-09'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , (15, '\xBADDD0', '\xCAFED0', '2016-06-22 19:10:33-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , (16, '\xBADDD0', '\xCAFED0', '2016-06-22 19:10:33-09'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1),
    (6, 'test-safari', 1),
    (7, 'howo', 1),
    (8, 'bassman077', 1),
    (9, 'spscontest', 1),
    (10, 'xenomorphosis', 1),
    (11, 'sloth.buzz', 1),
    (12, 'simple-app', 1),
    (13, 'dorrebeca2', 1),
    (14, 'margemnlpz08', 1),
    (15, 'steem.kit', 1),
    (16, 'jte1023', 1),
    (17, 'adedayoolumide', 1),
    (18, 'eos-polska', 1)
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
    -- account_update2_operation
        -- posting json metadata exists, json metadata empty
        ( 1, 1, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
        {
            "type": "account_update2_operation",
            "value": {
                "account": "test-safari",
                "json_metadata": "",
                "posting_json_metadata": "{\"profile\":{\"name\":\"Leonardo Da VinciXX\",\"about\":\"Renaissance man, vegetarian, inventor of the helicopter in 1512 and painter of the Mona Lisa..\",\"website\":\"http://www.davincilife.com/\",\"location\":\"Florence\",\"cover_image\":\"https://ichef.bbci.co.uk/news/912/cpsprodpb/CE63/production/_106653825_be212f00-f8c5-43d2-b4ad-f649e6dc4c1e.jpg\",\"profile_image\":\"https://www.parhlo.com/wp-content/uploads/2016/01/tmp617041537745813506.jpg\"}}",
                "extensions": []
            }
        }            
        '::jsonb::hive.operation),

        --empty json and posting metadata
        ( 2, 2, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_update2_operation",
                "value": {
                    "account": "howo",
                    "json_metadata": "{}",
                    "posting_json_metadata": "\"\"",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        ),

        ( 15, 15, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_update2_operation",
                "value": {
                    "account": "howo",
                    "json_metadata": "",
                    "posting_json_metadata": "",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        ),


        -- empty posting_metadata, json_metadata exists
        ( 3, 3, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_update2_operation",
                "value": {
                    "account": "bassman077",
                    "json_metadata": "{\"beneficiaries\":[{\"name\":\"oracle-d\",\"weight\":100,\"label\":\"creator\"},{\"name\":\"hiveonboard\",\"weight\":100,\"label\":\"provider\"},{\"name\":\"spk.beneficiary\",\"label\":\"referrer\",\"weight\":300}]}",
                    "posting_json_metadata": "",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        ),

        --posting metadata equal to ""
                ( 4, 4, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
        {
            "type": "account_update2_operation",
            "value": {
                "account": "spscontest",
                "json_metadata": "",
                "posting_json_metadata": "\"\"",
                "extensions": []
            }
        }'::jsonb::hive.operation),

        --posting_metadata equal to {}
        ( 5, 5, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '

            {
                "type": "account_update2_operation",
                "value": {
                    "account": "xenomorphosis",
                    "json_metadata": "",
                    "posting_json_metadata": "{}",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        ),

    -- account_create operation 
        -- empty json metadata
        ( 6, 6, 0, 0, 9, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_create_operation",
                "value": {
                    "fee": {
                        "amount": "3000",
                        "precision": 3,
                        "nai": "@@000000021"
                    },
                    "creator": "slothbuzz",
                    "new_account_name": "sloth.buzz",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM7ASBXDHEqM6mFo5eWWqn3EQUQVozAHo5BykoHzPwjFqnWtErqP",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6AmN98Z69K4aAAxTeUmddiVK8dTAPtEUULeZMUPZHDMAtz7L46",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6CiTK6H9PbB97qASd3XRPv27aidddGtaYJ6ygcnArjcty4VAXR",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM84bJQnKmM7rMAbsFPXZpQTQi5rBscbpuXkJ6XuVYEundE2Q1yx",
                    "json_metadata": "{}"
                }
            }'::jsonb::hive.operation),

        ( 16, 16, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_update2_operation",
                "value": {
                    "account": "sloth.buzz",
                    "json_metadata": "",
                    "posting_json_metadata": "",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        ),

        -- json metadata equal to  ""
        ( 7, 7, 0, 0, 9, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_create_operation",
                "value": {
                    "fee": {
                        "amount": "50000",
                        "precision": 3,
                        "nai": "@@000000021"
                    },
                    "creator": "busy.app",
                    "new_account_name": "simple-app",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM85c4CYb7pzdRZspo8GuRGJoA9fSS5d9Q98u5WmDct5qtjQqnLy",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM7GizTZAW9ehv1p7CyfNS8JEwVSFZZJWGNY9UZBhNzD3iaWSzAS",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6d8pyy352Zd5ZFSpajhkL4aUxTDpZXb1XGqA3vJjxLce8UU9w9",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM6NrLK9cwh9aAdouhSL3KhucAXU4ejReXF1vPvCeWXKrisMcoa8",
                    "json_metadata": "\"\""
                }
            }'::jsonb::hive.operation),

        --json metadata equal to {}
        ( 8, 8, 0, 0, 9, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_create_operation",
                "value": {
                    "fee": {
                        "amount": "3000",
                        "precision": 3,
                        "nai": "@@000000021"
                    },
                    "creator": "dorregonft",
                    "new_account_name": "dorrebeca2",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM5UPaZLPAdRTqhE4ymrRLYsVVxdARwXrjgnsxpgnGYxEZ4jUhwm",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM7renP4Af8yCHxmFoHsGzAJRGfdmQ9HKsXuRZQJkJtRxDWCTP5Q",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6ockHtuumKLqYRaN4e9PwsML82srpSMTTH6WS3AfsoQEbJFJnn",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM5eK3sJ42oUd6KB5AZU5AHXdxBBK6tcfw69rTx7phnHH3yBmQxk",
                    "json_metadata": "{}"
                }
            }'::jsonb::hive.operation),

        -- json metadata with a non empty value
        ( 9, 9, 0, 0, 9, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_create_operation",
                "value": {
                    "fee": {
                        "amount": "3000",
                        "precision": 3,
                        "nai": "@@000000021"
                    },
                    "creator": "wallet.creator",
                    "new_account_name": "margemnlpz08",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM7kstoZ2obmu5PcTYd9oAGeS9At5XcGYTtsL5sWjRM5VYG2bK3M",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM7xG5iWYDyaKsjj455s4cR32Eud9wGphKr6Tia3SkJvRUqZEyux",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM5pLwuFQs9i75tP2oiCDi6GwgRPP2pawq6TAcEVF9ydhNGweNtB",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM5Da24pp7ZztCipiUjp32eYxHXiQPDApY43PiMTfs9ivbhBrdgX",
                    "json_metadata": "{\"profile\":{\"about\":\"This account was instantly created via @hivewallet.app - available for iOS and Android!\",\"website\":\"https://hivewallet.app\"}}"
                }
            }'::jsonb::hive.operation
        ),

    -- account_create_with_delegation_operation 
        ( 10, 10, 0, 0, 41, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_create_with_delegation_operation",
                "value": {
                    "fee": {
                        "amount": "3000",
                        "precision": 3,
                        "nai": "@@000000021"
                    },
                    "delegation": {
                        "amount": "0",
                        "precision": 6,
                        "nai": "@@000000037"
                    },
                    "creator": "genievot",
                    "new_account_name": "steem.kit",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [
                            [
                                "steemconnect",
                                1
                            ]
                        ],
                        "key_auths": [
                            [
                                "STM82hFUKjN2j8KGqQ8rz9YgFAbMrWFuCPkabtrAnUfV2JQshNPLz",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [
                            [
                                "steemconnect",
                                1
                            ]
                        ],
                        "key_auths": [
                            [
                                "STM78mV5drS6a5SredobAJXvzZv7tvBo4Cj15rumRcBtMzTWT173a",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [
                            [
                                "steemconnect",
                                1
                            ]
                        ],
                        "key_auths": [
                            [
                                "STM6ZVzWQvbYSzVpY2PRJHu7QSASVy8aB8xSVcJgx5seYGHPFvJkZ",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM7o1DigBaUEF28n2ap5PeY9Jqhndz3zWmF7xZ3zfRgSqeLaMnyA",
                    "json_metadata": "{\"owner\":\"genievot\"}",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        ),

    -- account_update2_operation
        ( 11, 11, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
            {
            "type": "account_update2_operation",
                "value": {
                    "account": "jte1023",
                    "json_metadata": "{\"profile\":{\"name\":\"Jeremy\",\"about\":\"               \",\"cover_image\":\"https://files.peakd.com/file/peakd-hive/jte1023/7C47EDD4-517A-414B-8222-4DD365FB301A.jpeg\",\"profile_image\":\"https://files.peakd.com/file/peakd-hive/jte1023/1029B838-2E4B-4892-9E3A-964B9ABB168A.jpeg\",\"website\":\" \",\"location\":\"NC, USA\",\"pinned\":\"\",\"version\":2,\"portfolio\":\"enabled\",\"trail\":true,\"collections\":\"enabled\"}}",
                    "posting_json_metadata": "{\"profile\":{\"name\":\"Jeremy\",\"about\":\"               \",\"cover_image\":\"https://files.peakd.com/file/peakd-hive/jte1023/7C47EDD4-517A-414B-8222-4DD365FB301A.jpeg\",\"profile_image\":\"https://files.peakd.com/file/peakd-hive/jte1023/1029B838-2E4B-4892-9E3A-964B9ABB168A.jpeg\",\"website\":\" \",\"location\":\"NC, USA\",\"pinned\":\"\",\"version\":2,\"portfolio\":\"enabled\",\"trail\":true,\"collections\":\"enabled\"}}",
                    "extensions": []
                }
            }'::jsonb::hive.operation),

    -- account_update_operation 
        ( 12, 12, 0, 0, 10, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_update_operation",
                "value": {
                    "account": "adedayoolumide",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6RxYLCcVSFtscWcV9813Ag28bd57fRsGHRB8GRwvo8FoCJ7Rgt",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM7XDpuiCbACR1s1rX8qdbv3jJ4yA9BksTaCEoAAa4NWM7fjSdCf",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [
                            [
                                "dreply",
                                1
                            ],
                            [
                                "ecency.app",
                                1
                            ],
                            [
                                "hive.blog",
                                1
                            ],
                            [
                                "leofinance",
                                1
                            ],
                            [
                                "peakd.app",
                                1
                            ],
                            [
                                "steemauto",
                                1
                            ],
                            [
                                "threespeak",
                                1
                            ]
                        ],
                        "key_auths": [
                            [
                                "STM8BhQrZ8NYG9LXPsDohBtdDhW9ojn2y9Zj8kXcL1EP54Y5jD1BW",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM6jwfUrLcnd47hX87JQv6Q78UwUZm7RPAfjqjtQ2K7793Jsjuoy",
                    "json_metadata": "{\"beneficiaries\":[{\"name\":\"threespeak\",\"weight\":100,\"label\":\"creator\"},{\"name\":\"hiveonboard\",\"weight\":100,\"label\":\"provider\"}]}"
                }
            }'::jsonb::hive.operation),

    -- create_claimed_account_operation
        ( 13, 13, 0, 0, 23, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "create_claimed_account_operation",
                "value": {
                    "creator": "ocdb",
                    "new_account_name": "eos-polska",
                    "owner": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6GnfcJpf1ucXCwGx4DrvxX6n34xTN1T8kcwXe4ypxD3ULMsPCi",
                                1
                            ]
                        ]
                    },
                    "active": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM6S2sHwtvgneTwhxcP4r3kWTs5kVzuJzoJ2UbkTPxvQkSfDWnUh",
                                1
                            ]
                        ]
                    },
                    "posting": {
                        "weight_threshold": 1,
                        "account_auths": [],
                        "key_auths": [
                            [
                                "STM5C8xrJ8EcCGBNVFz58QMo4SmJGJTE6A74663weGADnC4bXbh6t",
                                1
                            ]
                        ]
                    },
                    "memo_key": "STM7xPdXrHmMe94pbqAeXSYsTYLhRagp3bRLcfu7yY43mu4xZfTT5",
                    "json_metadata": "{\"beneficiaries\":[{\"name\":\"fractalnode\",\"weight\":300,\"label\":\"referrer\"},{\"name\":\"ocdb\",\"weight\":100,\"label\":\"creator\"},{\"name\":\"hiveonboard\",\"weight\":100,\"label\":\"provider\"}]}",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        ),

        -- second update for the same account in the blocks range
        ( 14, 14, 0, 0, 43, '2016-06-22 19:10:21-07'::timestamp, '
            {
                "type": "account_update2_operation",
                "value": {
                    "account": "bassman077",
                    "json_metadata": "{\"maleficiaries\":[{\"name\":\"oracle-d\",\"weight\":100,\"label\":\"creator\"},{\"name\":\"hiveonboard\",\"weight\":100,\"label\":\"provider\"},{\"name\":\"spk.beneficiary\",\"label\":\"referrer\",\"weight\":300}]}",
                    "posting_json_metadata": "",
                    "extensions": []
                }
            }'::jsonb::hive.operation
        )


        ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'METADATA', 'context' );
    PERFORM hive.app_context_detach( 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 16;

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.update_state_provider_metadata(1, 16, 'context');
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM ASSERT_METADATA_VALUES(6 /*'test-safari'*/   , '','{"profile":{"name":"Leonardo Da VinciXX","about":"Renaissance man, vegetarian, inventor of the helicopter in 1512 and painter of the Mona Lisa..","website":"http://www.davincilife.com/","location":"Florence","cover_image":"https://ichef.bbci.co.uk/news/912/cpsprodpb/CE63/production/_106653825_be212f00-f8c5-43d2-b4ad-f649e6dc4c1e.jpg","profile_image":"https://www.parhlo.com/wp-content/uploads/2016/01/tmp617041537745813506.jpg"}}');
    PERFORM ASSERT_METADATA_VALUES(7 /*'howo'*/          , '{}', '""');
    PERFORM ASSERT_METADATA_VALUES(8 /*'bassman077'*/    , '{"maleficiaries":[{"name":"oracle-d","weight":100,"label":"creator"},{"name":"hiveonboard","weight":100,"label":"provider"},{"name":"spk.beneficiary","label":"referrer","weight":300}]}', '');
    PERFORM ASSERT_METADATA_VALUES(9 /*'spscontest'*/    ,'','""');
    PERFORM ASSERT_METADATA_VALUES(10 /*'xenomorphosis'*/,'','{}');
    PERFORM ASSERT_METADATA_VALUES(11 /*'sloth.buzz'*/   ,'{}','');
    PERFORM ASSERT_METADATA_VALUES(12 /*'simple-app'*/   ,'""','');
    PERFORM ASSERT_METADATA_VALUES(13 /*'dorrebeca2'*/   ,'{}','');
    PERFORM ASSERT_METADATA_VALUES(14 /*'margemnlpz08'*/ ,'{"profile":{"about":"This account was instantly created via @hivewallet.app - available for iOS and Android!","website":"https://hivewallet.app"}}','');
    PERFORM ASSERT_METADATA_VALUES(15 /*'steem.kit'*/    ,'{"owner":"genievot"}','');
    PERFORM ASSERT_METADATA_VALUES(16 /*'jte1023'*/      ,'{"profile":{"name":"Jeremy","about":"               ","cover_image":"https://files.peakd.com/file/peakd-hive/jte1023/7C47EDD4-517A-414B-8222-4DD365FB301A.jpeg","profile_image":"https://files.peakd.com/file/peakd-hive/jte1023/1029B838-2E4B-4892-9E3A-964B9ABB168A.jpeg","website":" ","location":"NC, USA","pinned":"","version":2,"portfolio":"enabled","trail":true,"collections":"enabled"}}', '{"profile":{"name":"Jeremy","about":"               ","cover_image":"https://files.peakd.com/file/peakd-hive/jte1023/7C47EDD4-517A-414B-8222-4DD365FB301A.jpeg","profile_image":"https://files.peakd.com/file/peakd-hive/jte1023/1029B838-2E4B-4892-9E3A-964B9ABB168A.jpeg","website":" ","location":"NC, USA","pinned":"","version":2,"portfolio":"enabled","trail":true,"collections":"enabled"}}');
    PERFORM ASSERT_METADATA_VALUES(17 /*'adedayoolumide'*/,'{"beneficiaries":[{"name":"threespeak","weight":100,"label":"creator"},{"name":"hiveonboard","weight":100,"label":"provider"}]}','');
    PERFORM ASSERT_METADATA_VALUES(18 /*'eos-polska'*/   ,'{"beneficiaries":[{"name":"fractalnode","weight":300,"label":"referrer"},{"name":"ocdb","weight":100,"label":"creator"},{"name":"hiveonboard","weight":100,"label":"provider"}]}','');

        --check overall operations used
    ASSERT hive.unordered_arrays_equal(
        (SELECT array_agg(t.get_metadata_operations) FROM hive.get_metadata_operations()t),
        (SELECT array_agg(t) FROM hive.get_metadata_operations_pattern()t)
    ), 'Broken hive.get_metadata_operations';

END;
$BODY$
;

CREATE OR REPLACE FUNCTION ASSERT_METADATA_VALUES(
    _account_id INTEGER,
    _json_metadata TEXT,
    _posting_json_metadata TEXT
    )
RETURNS void 
LANGUAGE 'plpgsql' 
STABLE AS
$BODY$
BEGIN ASSERT 1 = (
        SELECT COUNT(*)
        FROM hive.context_metadata
        WHERE _account_id = account_id AND
              _json_metadata = json_metadata AND
              _posting_json_metadata = posting_json_metadata
    ),
    'Unexpected metadata';
END
$BODY$;

CREATE OR REPLACE FUNCTION hive.get_metadata_operations_pattern()
RETURNS SETOF TEXT
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
RETURN QUERY
            SELECT 'hive::protocol::account_create_operation'
  UNION ALL SELECT 'hive::protocol::account_create_with_delegation_operation'
  UNION ALL SELECT 'hive::protocol::account_update2_operation'
  UNION ALL SELECT 'hive::protocol::account_update_operation'
  UNION ALL SELECT 'hive::protocol::create_claimed_account_operation'
;
END
$$;
