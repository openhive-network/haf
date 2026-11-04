CREATE OR REPLACE FUNCTION public.keyauth_rows( _operation hafd.operation )
    RETURNS TEXT[]
    LANGUAGE sql
    IMMUTABLE
AS
$BODY$
    SELECT array_agg(
        format( '%s|%s|%s|%s|%s|%s'
            , k.account_name
            , k.key_kind
            , CASE WHEN k.key_auth IS NULL THEN NULL ELSE hive.public_key_to_string( k.key_auth ) END
            , k.account_auth
            , k.weight_threshold
            , k.w )
        ORDER BY k.ordinality )
    FROM hive.get_keyauths( _operation ) WITH ORDINALITY k;
$BODY$
;

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
    __pow hafd.operation := '{
        "type": "pow_operation",
        "value": {
            "worker_account": "admin",
            "block_id": "000004433bd4602cf5f74dbb564183837df9cef8",
            "nonce": 82,
            "work": {
                "worker": "STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G",
                "input": "59b009f89477919f95914151cef06f28bf344dd6fb7670aca1c1f4323c80446b",
                "signature": "1f3f83209097efcd01b7d6f27ce726164323d503d6fcf4d55bfb7cb3032796f6766738b36062b5850d69447fdf9c091cbc70825df5eeacc4710a0b11ffdbf0912a",
                "work": "0b62f4837801cd857f01d6a541faeb13d6bb95f1c36c6b4b14a47df632aa6c92"
            },
            "props": {"account_creation_fee": {"amount": "100000", "precision": 3, "nai": "@@000000021"}, "maximum_block_size": 131072, "hbd_interest_rate": 1000}
        }
    }'::jsonb::hafd.operation;
    -- props are fc::raw-packed: "key" is STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G,
    -- "new_signing_key" is STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX
    __set_properties_keep_key hafd.operation := '{
        "type": "witness_set_properties_operation",
        "value": {
            "owner": "holger80",
            "props": [["key", "029db013797711c88cccca3692407f9ff9b9ce7221aaa2d797f1692be2215d0a5f"]],
            "extensions": []
        }
    }'::jsonb::hafd.operation;
    __set_properties_new_key hafd.operation := '{
        "type": "witness_set_properties_operation",
        "value": {
            "owner": "holger80",
            "props": [["key", "029db013797711c88cccca3692407f9ff9b9ce7221aaa2d797f1692be2215d0a5f"], ["new_signing_key", "03bc5cd80588b23948aaa1e65be1a8b32cd9bed062a346c471c9319e62ba82a9ef"]],
            "extensions": []
        }
    }'::jsonb::hafd.operation;
    __rows TEXT[];
BEGIN
    __rows := public.keyauth_rows( __account_create );

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

    -- pow creates the witness with the worker key as its block signing key
    __rows := public.keyauth_rows( __pow );
    ASSERT __rows = ARRAY[
          'admin|OWNER|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'admin|ACTIVE|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'admin|POSTING|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'admin|MEMO|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||0|0'
        , 'admin|WITNESS_SIGNING|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'admin|WITNESS_SIGNING|||1|0'
    ], format( 'Unexpected authorities of pow_operation: %s', __rows );

    __rows := public.keyauth_rows( __set_properties_keep_key );
    ASSERT __rows = ARRAY[
          'holger80|WITNESS_SIGNING|STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G||1|1'
        , 'holger80|WITNESS_SIGNING|||1|0'
    ], format( 'Unexpected authorities of witness_set_properties_operation without new_signing_key: %s', __rows );

    -- the witness signs blocks with new_signing_key from now on, not with the authorizing "key"
    __rows := public.keyauth_rows( __set_properties_new_key );
    ASSERT __rows = ARRAY[
          'holger80|WITNESS_SIGNING|STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX||1|1'
        , 'holger80|WITNESS_SIGNING|||1|0'
    ], format( 'Unexpected authorities of witness_set_properties_operation with new_signing_key: %s', __rows );

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
