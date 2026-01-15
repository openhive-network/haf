CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    test_signature TEXT;
    recovered_pubkey TEXT;
    recovered_pubkey2 TEXT;
    test_transaction JSONB;
    default_chain_id TEXT := 'beeab0de00000000000000000000000000000000000000000000000000000000';
    custom_chain_id TEXT := '4200000000000000000000000000000000000000000000000000000000000000';
BEGIN
    -- Test basic signature recovery with real transaction signature
    test_transaction := '{"ref_block_num":30,"ref_block_prefix":1561542156,"expiration":"2023-01-02T11:26:57","operations":[{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"10000","precision":3,"nai":"@@000000021"},"memo":"memo"}}],"extensions":[],"signatures":[]}'::JSONB;
    BEGIN
        test_signature := '1fe49e20f7b64efb3316d8921930c417c5cf63c73b7d8a15ceeb5493132c6cef6e5727feee25e01826e17e0c810083ad356245a6491b6b78e08e234076a68d8ba7';
        recovered_pubkey := hive.pubkey_from_signature(test_signature, hive.transaction_sig_digest(test_transaction, default_chain_id));
        recovered_pubkey2 := hive.pubkey_from_signature(test_signature, hive.transaction_sig_digest(test_transaction, custom_chain_id));
        ASSERT recovered_pubkey IS NOT NULL, 'Recovered public key should not be null';
        ASSERT length(recovered_pubkey) > 0, 'Recovered public key should not be empty';
        ASSERT recovered_pubkey = 'STM84HUbyJV7NzXvgvngUpuDtxehAjW9mzREaLMUkxDF9b8YM1fcC', 'Recovered public key does not match: ' || recovered_pubkey;
        ASSERT recovered_pubkey != recovered_pubkey2, 'Recovered public keys should be different for different chain IDs';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Test 1 failed: % %', SQLERRM, SQLSTATE;
    END;

    -- Test signature recovery with vote operation transaction
    test_transaction := '{"ref_block_num":30,"ref_block_prefix":1561542156,"expiration":"2023-01-02T11:26:57","operations":[{"type":"vote_operation","value":{"voter":"initminer","author":"alice","permlink":"permlink","weight":1000}}],"extensions":[],"signatures":[]}'::JSONB;
    BEGIN
        test_signature := '1fbb4364d1c5704883b65f61cb2bc705049fbcbb3f4a309192c8b0778168ee06e949b2e4b5bf9abe63b9a75237d588b248cc3747d7170c23ee63ecdeb13506ccb7';
        recovered_pubkey := hive.pubkey_from_signature(test_signature, hive.transaction_sig_digest(test_transaction, default_chain_id));
        recovered_pubkey2 := hive.pubkey_from_signature(test_signature, hive.transaction_sig_digest(test_transaction, custom_chain_id));
        ASSERT recovered_pubkey IS NOT NULL, 'Recovered public key should not be null';
        ASSERT length(recovered_pubkey) > 0, 'Recovered public key should not be empty';
        ASSERT recovered_pubkey = 'STM5e7pCtzMuvhX36DydxJ5tUcn7Qo52SyeUG8skuBeXJR6mUC62T', 'Recovered public key does not match: ' || recovered_pubkey;
        ASSERT recovered_pubkey != recovered_pubkey2, 'Recovered public keys should be different for different chain IDs';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Test 2 failed: % %', SQLERRM, SQLSTATE;
    END;

    -- Test signature recovery with comment operation transaction
    test_transaction := '{"ref_block_num":30,"ref_block_prefix":1561542156,"expiration":"2023-01-02T11:26:57","operations":[{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"someone","author":"bob","permlink":"test-permlink","title":"test-title","body":"this is a body","json_metadata":"{}"}}],"extensions":[],"signatures":[]}'::JSONB;
    BEGIN
        test_signature := '1fdb985e6594f08bd9d926b7b7831f273174239ff812afa8a571471e0e02eef52a4d7c30c4fe7125e96de2ebc8afb91b7f6ce12442a9f22aa8444382ed19c1dde5';
        recovered_pubkey := hive.pubkey_from_signature(test_signature, hive.transaction_sig_digest(test_transaction, default_chain_id));
        recovered_pubkey2 := hive.pubkey_from_signature(test_signature, hive.transaction_sig_digest(test_transaction, custom_chain_id));
        ASSERT recovered_pubkey IS NOT NULL, 'Recovered public key should not be null';
        ASSERT length(recovered_pubkey) > 0, 'Recovered public key should not be empty';
        ASSERT recovered_pubkey = 'STM7GyombosxpVm94isg7rogUqzEqRvGCh2CqF8fFe5WuqU622m93', 'Recovered public key does not match: ' || recovered_pubkey;
        ASSERT recovered_pubkey != recovered_pubkey2, 'Recovered public keys should be different for different chain IDs';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Test 3 failed: % %', SQLERRM, SQLSTATE;
    END;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Test failed: % %', SQLERRM, SQLSTATE;
END;
$BODY$
;
