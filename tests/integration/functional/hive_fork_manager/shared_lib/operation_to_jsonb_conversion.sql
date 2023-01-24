DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    --Nothing to do
END;
$BODY$
;

DROP FUNCTION IF EXISTS ASSERT_THIS_TEST;
CREATE FUNCTION ASSERT_THIS_TEST(op TEXT)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT op::hive.operation::jsonb = op::jsonb), 'Incorrect conversion from operation to jsonb';
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
  PERFORM ASSERT_THIS_TEST('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}');
  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}');
  PERFORM ASSERT_THIS_TEST('{"type": "pow_operation", "value": {"work": {"work": "00000089714c32dce184406b658b7cdad39779ac751d8713e0b0ea5dc1500a7e", "input": "ebfbdb9fe886d41b8b0a354d4f4b21f7b509c21c76cd0edc4f18329803366a32", "worker": "STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G", "signature": "1f77ec5334c005791caac1644e6ab67da951388cc2b35866801fcf7d04d15dc8c07ac3b7d60e4f690a36fc8204a267e7471f0e278b7bc998c7be1a55c8f5e4e644"}, "nonce": 13371292260756155458, "props": {"hbd_interest_rate": 1000, "maximum_block_size": 131072, "account_creation_fee": {"nai": "@@000000021", "amount": "100000", "precision": 3}}, "block_id": "00000b12facff059ff17895eb1898f825d2aa470", "worker_account": "any"}}');
  PERFORM ASSERT_THIS_TEST('{"type": "effective_comment_vote_operation", "value": {"voter": "dantheman", "author": "red", "weight": 33132337607, "rshares": 375241, "permlink": "red-dailydecrypt-1", "pending_payout": {"nai": "@@000000013", "amount": "0", "precision": 3}, "total_vote_weight": 919264341405}}');
  PERFORM ASSERT_THIS_TEST('{"type": "pow2_operation", "value": {"work": {"type": "pow2", "value": {"input": {"nonce": 1307921963190636023, "prev_block": "003ea8449a6f762f118d20e97c47164070e3ee42", "worker_account": "craigslist"}, "pow_summary": 3897898258}}, "props": {"hbd_interest_rate": 1000, "maximum_block_size": 131072, "account_creation_fee": {"nai": "@@000000021", "amount": "1", "precision": 3}}}}');
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
    --Nothing to do
END;
$BODY$
;


