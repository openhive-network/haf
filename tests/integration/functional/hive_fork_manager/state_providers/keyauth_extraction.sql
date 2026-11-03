CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __account_create hafd.operation := '{
        "type": "account_create_operation",
        "value": {
            "fee": {"amount": "10000", "precision": 3, "nai": "@@000000021"},
            "creator": "steem",
            "new_account_name": "andresricou",
            "owner": {"weight_threshold": 1, "account_auths": [], "key_auths": [["STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh", 1]]},
            "active": {"weight_threshold": 1, "account_auths": [], "key_auths": [["STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG", 1]]},
            "posting": {"weight_threshold": 2, "account_auths": [["ecency.app", 1], ["good-karma", 3]], "key_auths": [["STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9", 1]]},
            "memo_key": "STM6XUnQxSzLpUM6FMnuTTyG9LNXvzYbzW2J6qGH5sRTsQvCnGePo",
            "json_metadata": ""
        }
    }'::jsonb::hafd.operation;
    __rows TEXT[];
BEGIN
    SELECT array_agg(
        format( '%s|%s|%s|%s|%s|%s'
            , k.account_name
            , k.key_kind
            , CASE WHEN k.key_auth IS NULL THEN NULL ELSE hive.public_key_to_string( k.key_auth ) END
            , k.account_auth
            , k.weight_threshold
            , k.w )
        ORDER BY k.ordinality )
    FROM hive.get_keyauths( __account_create ) WITH ORDINALITY k
    INTO __rows;

    ASSERT __rows = ARRAY[
          'andresricou|OWNER|STM7x48ngjo2L7eNxj3u5dUnanQovAUc4BrcbRFbP8BSAS4SBxmHh||1|1'
        , 'andresricou|OWNER|||1|0'
        , 'andresricou|ACTIVE|STM4w4znpS1jgFLAL4BGvJpqMgyn38N9FLGbP4x1cvYP1nqDYNonG||1|1'
        , 'andresricou|ACTIVE|||1|0'
        , 'andresricou|POSTING|STM6JfQQyvVdmnf3Ch5ehJMpAEfpRswMmJQP9MMvJBjszf32xmvn9||2|1'
        , 'andresricou|POSTING||ecency.app|2|1'
        , 'andresricou|POSTING||good-karma|2|3'
        , 'andresricou|MEMO|STM6XUnQxSzLpUM6FMnuTTyG9LNXvzYbzW2J6qGH5sRTsQvCnGePo||0|0'
    ], format( 'Unexpected authorities of account_create_operation: %s', __rows );

    ASSERT ( SELECT COUNT(*) FROM hive.get_keyauths( '{"type": "vote_operation", "value": {"voter": "a", "author": "b", "permlink": "c", "weight": 1}}'::jsonb::hafd.operation ) ) = 0
        , 'vote_operation should carry no authorities';

    ASSERT EXISTS ( SELECT 1 FROM hive.get_genesis_keyauths() WHERE account_name = 'initminer' AND key_kind = 'OWNER' )
        , 'Genesis authorities do not set the initminer owner authority';

    ASSERT EXISTS ( SELECT 1 FROM hive.get_hf09_keyauths() ), 'HF09 authorities are empty';
    ASSERT EXISTS ( SELECT 1 FROM hive.get_hf21_keyauths() ), 'HF21 authorities are empty';
    ASSERT EXISTS ( SELECT 1 FROM hive.get_hf24_keyauths() ), 'HF24 authorities are empty';
END;
$BODY$
;
