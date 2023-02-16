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
  -- Make sure direct conversion (operation::jsonb) results in the same jsonb as indirect one (operation::text::jsonb).
  ASSERT ( SELECT op::hive.operation::text::jsonb = op::hive.operation::jsonb), 'operation::text::jsonb conversion doesn''t match operation::jsonb conversion';

  -- Make sure operation converted to jsonb can be converted back to operation of equal value.
  ASSERT ( SELECT op::hive.operation::jsonb::text::hive.operation = op::hive.operation), 'Converting operation to jsonb and back doesn''t match original operation';
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
  -- Make sure that integer < 0xffffffff is converted to jsonb as numeric type
  ASSERT (select '{"type":"pow_operation","value":{"worker_account":"sminer10","block_id":"00015d56d6e721ede5aad1babb0fe818203cbeeb","nonce":"42","work":{"worker":"STM6tC4qRjUPKmkqkug5DvSgkeND5DHhnfr3XTgpp4b4nejMEwn9k","input":"c55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b","signature":"1fbce97f375ac548c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81aa","work":"000000049711861bce6185671b672696eca64398586a66319eacd875155b77fc"},"props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}'::hive.operation::jsonb #> '{"value", "nonce"}' = '42'::jsonb), 'Small nonce value should be converted to jsonb as numeric type';

  -- Make sure that integer > 0xffffffff is converted to jsonb as string type
  ASSERT (select '{"type":"pow_operation","value":{"worker_account":"sminer10","block_id":"00015d56d6e721ede5aad1babb0fe818203cbeeb","nonce":"682570897433907950","work":{"worker":"STM6tC4qRjUPKmkqkug5DvSgkeND5DHhnfr3XTgpp4b4nejMEwn9k","input":"c55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b","signature":"1fbce97f375ac548c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81aa","work":"000000049711861bce6185671b672696eca64398586a66319eacd875155b77fc"},"props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}'::hive.operation::jsonb #> '{"value", "nonce"}' = '"682570897433907950"'::jsonb), 'Large nonce value should be converted to jsonb as string type';

  -- Make sure that integer = 0xffffffff is converted to jsonb as numeric type
  ASSERT (select '{"type":"limit_order_cancel_operation","value":{"owner":"complexring","orderid":4294967295}}'::hive.operation::jsonb #> '{"value", "orderid"}' = '4294967295'::jsonb), '4294967295 value should be converted to jsonb as numeric type';

  -- Make sure that negative integer is converted to jsonb as numeric type
  ASSERT (select '{"type":"vote_operation","value":{"voter":"dantheman","author":"red","permlink":"888","weight":-100}}'::hive.operation::jsonb #> '{"value", "weight"}' = '-100'::jsonb), 'Negative value should be converted to jsonb as numeric type';

  -- Make sure that boolean values are converted to textual form
  ASSERT (select '{"type": "account_witness_vote_operation", "value": {"account": "donalddrumpf", "approve": true, "witness": "berniesanders"}}'::hive.operation::jsonb #> '{"value", "approve"}' = 'true'::jsonb), 'Boolean true should be converted to textual form';
  ASSERT (select '{"type": "account_witness_vote_operation", "value": {"account": "donalddrumpf", "approve": false, "witness": "berniesanders"}}'::hive.operation::jsonb #> '{"value", "approve"}' = 'false'::jsonb), 'Boolean false should be converted to textual form';

  PERFORM ASSERT_THIS_TEST('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}');
  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}');
  PERFORM ASSERT_THIS_TEST('{"type": "pow_operation", "value": {"work": {"work": "00000089714c32dce184406b658b7cdad39779ac751d8713e0b0ea5dc1500a7e", "input": "ebfbdb9fe886d41b8b0a354d4f4b21f7b509c21c76cd0edc4f18329803366a32", "worker": "STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G", "signature": "1f77ec5334c005791caac1644e6ab67da951388cc2b35866801fcf7d04d15dc8c07ac3b7d60e4f690a36fc8204a267e7471f0e278b7bc998c7be1a55c8f5e4e644"}, "nonce": 13371292260756155458, "props": {"hbd_interest_rate": 1000, "maximum_block_size": 131072, "account_creation_fee": {"nai": "@@000000021", "amount": "100000", "precision": 3}}, "block_id": "00000b12facff059ff17895eb1898f825d2aa470", "worker_account": "any"}}');
  PERFORM ASSERT_THIS_TEST('{"type": "effective_comment_vote_operation", "value": {"voter": "dantheman", "author": "red", "weight": 33132337607, "rshares": 375241, "permlink": "red-dailydecrypt-1", "pending_payout": {"nai": "@@000000013", "amount": "0", "precision": 3}, "total_vote_weight": 919264341405}}');
  PERFORM ASSERT_THIS_TEST('{"type": "pow2_operation", "value": {"work": {"type": "pow2", "value": {"input": {"nonce": 1307921963190636023, "prev_block": "003ea8449a6f762f118d20e97c47164070e3ee42", "worker_account": "craigslist"}, "pow_summary": 3897898258}}, "props": {"hbd_interest_rate": 1000, "maximum_block_size": 131072, "account_creation_fee": {"nai": "@@000000021", "amount": "1", "precision": 3}}}}');
  PERFORM ASSERT_THIS_TEST('{"type":"pow_operation","value":{"worker_account":"sminer10","block_id":"00015d56d6e721ede5aad1babb0fe818203cbeeb","nonce":"682570897433907950","work":{"worker":"STM6tC4qRjUPKmkqkug5DvSgkeND5DHhnfr3XTgpp4b4nejMEwn9k","input":"c55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b","signature":"1fbce97f375ac548c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81aa","work":"000000049711861bce6185671b672696eca64398586a66319eacd875155b77fc"},"props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}');
  PERFORM ASSERT_THIS_TEST('{"type": "account_create_operation", "value": {"fee": {"nai": "@@000000021", "amount": "0", "precision": 3}, "owner": {"key_auths": [["STM8MN3FNBa8WbEpxz3wGL3L1mkt6sGnncH8iuto7r8Wa3T9NSSGT", 1]], "account_auths": [], "weight_threshold": 1}, "active": {"key_auths": [["STM8HCf7QLUexogEviN8x1SpKRhFwg2sc8LrWuJqv7QsmWrua6ZyR", 1]], "account_auths": [], "weight_threshold": 1}, "creator": "hello", "posting": {"key_auths": [["STM8EhGWcEuQ2pqCKkGHnbmcTNpWYZDjGTT7ketVBp4gUStDr2brz", 1]], "account_auths": [], "weight_threshold": 1}, "memo_key": "STM6Gkj27XMkoGsr4zwEvkjNhh4dykbXmPFzHhT8g86jWsqu3U38X", "json_metadata": "{}", "new_account_name": "fabian"}}');
  PERFORM ASSERT_THIS_TEST('{"type": "comment_reward_operation", "value": {"author": "abit", "payout": {"nai": "@@000000013", "amount": "332", "precision": 3}, "permlink": "spam", "author_rewards": 755, "total_payout_value": {"nai": "@@000000013", "amount": "165", "precision": 3}, "curator_payout_value": {"nai": "@@000000013", "amount": "166", "precision": 3}, "beneficiary_payout_value": {"nai": "@@000000013", "amount": "0", "precision": 3}}}');
  PERFORM ASSERT_THIS_TEST('{"type":"witness_set_properties_operation","value":{"owner":"holger80","props":[["account_creation_fee","b80b00000000000003535445454d0000"],["key",    "0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"]],"extensions":[]}}');
  PERFORM ASSERT_THIS_TEST('{"type": "comment_operation", "value": {"author": "tattoodjay", "body": "This is a cross post of [@tattoodjay/wednesday-walk-in-buttonwood-park](/hive-194913/@tattoodjay/wednesday-walk-in-buttonwood-park) by @tattoodjay.<br><br>A walk around Buttonwood Park", "json_metadata": "{\"app\":\"peakd/2023.2.2\",\"tags\":[\"cross-post\"],\"image\":[],\"original_author\":\"tattoodjay\",\"original_permlink\":\"wednesday-walk-in-buttonwood-park\"}", "parent_author": "", "parent_permlink": "hive-155530", "permlink": "wednesday-walk-in-buttonwood-park-hive-155530", "title": "Wednesday Walk in Buttonwood Park"}}');
  PERFORM ASSERT_THIS_TEST('{"type": "comment_options_operation", "value": {"allow_curation_rewards": false, "allow_votes": true, "author": "tattoodjay", "extensions": [], "max_accepted_payout": {"nai": "@@000000013", "amount": "332", "precision": 3}, "percent_hbd": 10000, "permlink": "wednesday-walk-in-buttonwood-park-hive-155530"}}');
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


