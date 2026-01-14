CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    test_digest TEXT;
    test_digest2 TEXT;
    test_digest3 TEXT;
    test_pubkey TEXT;
    recovered_pubkey TEXT;
    default_chain_id TEXT := 'beeab0de00000000000000000000000000000000000000000000000000000000';
    custom_chain_id TEXT := '4200000000000000000000000000000000000000000000000000000000000000';
BEGIN
    -- Test simple transfer transaction with default chain_id
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":1097,"ref_block_prefix":2181793527,"expiration":"2016-03-24T18:00:21","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for valid transaction';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters (SHA256 hex)';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test same transaction with explicit default chain_id should produce same digest
    test_digest2 := hive.transaction_sig_digest(
        '{"ref_block_num":1097,"ref_block_prefix":2181793527,"expiration":"2016-03-24T18:00:21","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}',
        default_chain_id
    );
    ASSERT test_digest2 IS NOT NULL, 'Digest should not be null';
    ASSERT length(test_digest2) = 64, 'Digest should be 64 characters (SHA256 hex)';
    ASSERT test_digest2 = test_digest, 'Explicit default chain ID should produce the same digest';
    ASSERT test_digest2 ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test same transaction with different chain_id should produce different digest
    test_digest3 := hive.transaction_sig_digest(
        '{"ref_block_num":1097,"ref_block_prefix":2181793527,"expiration":"2016-03-24T18:00:21","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}',
        custom_chain_id
    );
    ASSERT test_digest3 IS NOT NULL, 'Digest should not be null';
    ASSERT length(test_digest3) = 64, 'Digest should be 64 characters (SHA256 hex)';
    ASSERT test_digest3 != test_digest2, 'Different chain_id should produce different digest';
    ASSERT test_digest3 ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with multiple operations
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":1234,"ref_block_prefix":567890123,"expiration":"2016-03-24T19:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"first"}},{"type":"transfer_operation","value":{"from":"bob","to":"charlie","amount":{"amount":"500","precision":3,"nai":"@@000000021"},"memo":"second"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for multi-op transaction';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest != test_digest2, 'Different transaction should produce different digest';
    ASSERT test_digest != test_digest3, 'Different transaction should produce different digest';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with vote operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":5000,"ref_block_prefix":123456789,"expiration":"2016-03-25T12:00:00","operations":[{"type":"vote_operation","value":{"voter":"alice","author":"bob","permlink":"test-post","weight":10000}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for vote operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with comment operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":6000,"ref_block_prefix":987654321,"expiration":"2016-03-26T08:30:00","operations":[{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"test","author":"alice","permlink":"my-post","title":"Test Post","body":"This is a test","json_metadata":"{}"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for comment operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with account_create operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":30,"ref_block_prefix":1561542156,"expiration":"2023-01-02T11:26:57","operations":[{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"dan","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"memo_key":"STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH","json_metadata":"{}"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for account_create operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with witness_update operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":30,"ref_block_prefix":1561542156,"expiration":"2023-01-02T11:26:57","operations":[{"type":"witness_update_operation","value":{"owner":"alice","url":"http://url.html","block_signing_key":"STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW","props":{"account_creation_fee":{"amount":"10000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for witness_update operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with custom_json operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":9000,"ref_block_prefix":777888999,"expiration":"2016-03-29T16:00:00","operations":[{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["alice"],"id":"follow","json":"{\"follower\":\"alice\",\"following\":\"bob\",\"what\":[\"blog\"]}"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for custom_json operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with transfer_to_vesting operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":10000,"ref_block_prefix":123123123,"expiration":"2016-03-30T18:00:00","operations":[{"type":"transfer_to_vesting_operation","value":{"from":"alice","to":"bob","amount":{"amount":"100000","precision":3,"nai":"@@000000021"}}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for transfer_to_vesting operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with withdraw_vesting operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":11000,"ref_block_prefix":456456456,"expiration":"2016-03-31T20:00:00","operations":[{"type":"withdraw_vesting_operation","value":{"account":"alice","vesting_shares":{"amount":"1000000000","precision":6,"nai":"@@000000037"}}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for withdraw_vesting operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with limit_order_create operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":12000,"ref_block_prefix":789789789,"expiration":"2016-04-01T10:00:00","operations":[{"type":"limit_order_create_operation","value":{"owner":"alice","orderid":12345,"amount_to_sell":{"amount":"100000","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"10000","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2016-04-02T10:00:00"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for limit_order_create operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with limit_order_cancel operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":13000,"ref_block_prefix":321321321,"expiration":"2016-04-02T12:00:00","operations":[{"type":"limit_order_cancel_operation","value":{"owner":"alice","orderid":12345}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for limit_order_cancel operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with feed_publish operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":14000,"ref_block_prefix":654654654,"expiration":"2016-04-03T14:00:00","operations":[{"type":"feed_publish_operation","value":{"publisher":"alice","exchange_rate":{"base":{"amount":"1000","precision":3,"nai":"@@000000013"},"quote":{"amount":"10000","precision":3,"nai":"@@000000021"}}}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for feed_publish operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test transaction with convert operation
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":15000,"ref_block_prefix":987987987,"expiration":"2016-04-04T16:00:00","operations":[{"type":"convert_operation","value":{"owner":"alice","requestid":54321,"amount":{"amount":"10000","precision":3,"nai":"@@000000013"}}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest IS NOT NULL, 'Digest should not be null for convert operation';
    ASSERT length(test_digest) = 64, 'Digest should be 64 characters';
    ASSERT test_digest ~ '^[0-9a-f]{64}$', 'Digest must be lowercase hex';

    -- Test different ref_block_num should produce different digest
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":1000,"ref_block_prefix":2000000000,"expiration":"2016-04-05T12:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}'
    );
    test_digest2 := hive.transaction_sig_digest(
        '{"ref_block_num":1001,"ref_block_prefix":2000000000,"expiration":"2016-04-05T12:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest != test_digest2, 'Different ref_block_num should produce different digest';

    -- Test different expiration should produce different digest
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":1000,"ref_block_prefix":2000000000,"expiration":"2016-04-05T12:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}'
    );
    test_digest2 := hive.transaction_sig_digest(
        '{"ref_block_num":1000,"ref_block_prefix":2000000000,"expiration":"2016-04-05T13:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest != test_digest2, 'Different expiration should produce different digest';

    -- Test different memo should produce different digest
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":1000,"ref_block_prefix":2000000000,"expiration":"2016-04-05T12:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"memo1"}}],"extensions":[],"signatures":[]}'
    );
    test_digest2 := hive.transaction_sig_digest(
        '{"ref_block_num":1000,"ref_block_prefix":2000000000,"expiration":"2016-04-05T12:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"memo2"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest != test_digest2, 'Different memo should produce different digest';

    -- Test different amount should produce different digest
    test_digest := hive.transaction_sig_digest(
        '{"ref_block_num":1000,"ref_block_prefix":2000000000,"expiration":"2016-04-05T12:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}'
    );
    test_digest2 := hive.transaction_sig_digest(
        '{"ref_block_num":1000,"ref_block_prefix":2000000000,"expiration":"2016-04-05T12:00:00","operations":[{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"6000","precision":3,"nai":"@@000000021"},"memo":"test"}}],"extensions":[],"signatures":[]}'
    );
    ASSERT test_digest != test_digest2, 'Different amount should produce different digest';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Test failed: % %', SQLERRM, SQLSTATE;
END;
$BODY$
;
