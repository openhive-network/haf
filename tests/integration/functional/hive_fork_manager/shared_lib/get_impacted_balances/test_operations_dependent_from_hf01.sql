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

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
  _pattern0_before_hf01 hive.impacted_balances_return[] = '{"(ocrdu,17,3,21)","(ocrdu,11,3,13)","(ocrdu,185025103000000,6,37)"}';
  _test0_before_hf01 hive.impacted_balances_return[];

  _pattern0_after_hf01 hive.impacted_balances_return[] = '{"(ocrdu,17,3,21)","(ocrdu,11,3,13)","(ocrdu,185025103,6,37)"}';
  _test0_after_hf01 hive.impacted_balances_return[];

  _pattern1_before_hf01 hive.impacted_balances_return[] = '{"(randaletouri,710,3,21)","(randaletouri,-26475000000,6,37)"}';
  _test1_before_hf01 hive.impacted_balances_return[];

  _pattern1_after_hf01 hive.impacted_balances_return[] = '{"(randaletouri,710,3,21)","(randaletouri,-26475,6,37)"}';
  _test1_after_hf01 hive.impacted_balances_return[];

  _pattern2_before_hf01 hive.impacted_balances_return[] = '{"(faddy,357000000000000,6,37)","(faddy,-357000,3,21)"}';
  _test2_before_hf01 hive.impacted_balances_return[];

  _pattern2_after_hf01 hive.impacted_balances_return[] = '{"(faddy,357000000,6,37)","(faddy,-357000,3,21)"}';
  _test2_after_hf01 hive.impacted_balances_return[];

  _pattern3_before_hf01 hive.impacted_balances_return[] = '{"(kaylinart,9048,3,13)","(kaylinart,5790,3,21)","(kaylinart,67826998226000000,6,37)"}';
  _test3_before_hf01 hive.impacted_balances_return[];

  _pattern3_after_hf01 hive.impacted_balances_return[] = '{"(kaylinart,9048,3,13)","(kaylinart,5790,3,21)","(kaylinart,67826998226,6,37)"}';
  _test3_after_hf01 hive.impacted_balances_return[];

  _pattern4_before_hf01 hive.impacted_balances_return[] = '{"(initminer,1000000000000,6,37)"}';
  _test4_before_hf01 hive.impacted_balances_return[];

  _pattern4_after_hf01 hive.impacted_balances_return[] = '{"(initminer,1000000,6,37)"}';
  _test4_after_hf01 hive.impacted_balances_return[];

  _pattern5_before_hf01 hive.impacted_balances_return[] = '{"(murdock5,-100000,3,21)","(null,100000,3,21)"}';
  _test5_before_hf01 hive.impacted_balances_return[];

  _pattern5_after_hf01 hive.impacted_balances_return[] = '{"(murdock5,-100000,3,21)","(null,100000,3,21)"}';
  _test5_after_hf01 hive.impacted_balances_return[];

  _pattern6_before_hf01 hive.impacted_balances_return[] = '{"(steemroller,2623363281000000,6,37)"}';
  _test6_before_hf01 hive.impacted_balances_return[];

  _pattern6_after_hf01 hive.impacted_balances_return[] = '{"(steemroller,2623363281,6,37)"}';
  _test6_after_hf01 hive.impacted_balances_return[];

  _pattern7_before_hf01 hive.impacted_balances_return[] = '{"(witnesses,72763034396000000,6,37)"}';
  _test7_before_hf01 hive.impacted_balances_return[];

  _pattern7_after_hf01 hive.impacted_balances_return[] = '{"(witnesses,72763034396,6,37)"}';
  _test7_after_hf01 hive.impacted_balances_return[];

  _pattern8_before_hf01 hive.impacted_balances_return[] = '{"(dpoll.curation,27,3,13)","(dpoll.curation,2,3,21)","(dpoll.curation,118862104000000,6,37)"}';
  _test8_before_hf01 hive.impacted_balances_return[];

  _pattern8_after_hf01 hive.impacted_balances_return[] = '{"(dpoll.curation,27,3,13)","(dpoll.curation,2,3,21)","(dpoll.curation,118862104,6,37)"}';
  _test8_after_hf01 hive.impacted_balances_return[];

BEGIN

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test0_before_hf01
FROM hive.get_impacted_balances('{"type":"claim_reward_balance_operation","value":{"account":"ocrdu","reward_hive":{"amount":"17","precision":3,"nai":"@@000000021"},"reward_hbd":{"amount":"11","precision":3,"nai":"@@000000013"},"reward_vests":{"amount":"185025103","precision":6,"nai":"@@000000037"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test0_after_hf01
FROM hive.get_impacted_balances('{"type":"claim_reward_balance_operation","value":{"account":"ocrdu","reward_hive":{"amount":"17","precision":3,"nai":"@@000000021"},"reward_hbd":{"amount":"11","precision":3,"nai":"@@000000013"},"reward_vests":{"amount":"185025103","precision":6,"nai":"@@000000037"}}}', TRUE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test1_before_hf01
FROM hive.get_impacted_balances('{"type":"fill_vesting_withdraw_operation","value":{"from_account":"randaletouri","to_account":"randaletouri","withdrawn":{"amount":"26475","precision":6,"nai":"@@000000037"},"deposited":{"amount":"710","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test1_after_hf01
FROM hive.get_impacted_balances('{"type":"fill_vesting_withdraw_operation","value":{"from_account":"randaletouri","to_account":"randaletouri","withdrawn":{"amount":"26475","precision":6,"nai":"@@000000037"},"deposited":{"amount":"710","precision":3,"nai":"@@000000021"}}}', TRUE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test2_before_hf01
FROM hive.get_impacted_balances('{"type":"transfer_to_vesting_completed_operation","value":{"from_account":"faddy","to_account":"faddy","hive_vested":{"amount":"357000","precision":3,"nai":"@@000000021"},"vesting_shares_received":{"amount":"357000000","precision":6,"nai":"@@000000037"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test2_after_hf01
FROM hive.get_impacted_balances('{"type":"transfer_to_vesting_completed_operation","value":{"from_account":"faddy","to_account":"faddy","hive_vested":{"amount":"357000","precision":3,"nai":"@@000000021"},"vesting_shares_received":{"amount":"357000000","precision":6,"nai":"@@000000037"}}}', TRUE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test3_before_hf01
FROM hive.get_impacted_balances('{"type":"author_reward_operation","value":{"author":"kaylinart","permlink":"should-you-start-a-drop-shipping-business","hbd_payout":{"amount":"9048","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"5790","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"67826998226","precision":6,"nai":"@@000000037"},"curators_vesting_payout":{"amount":"16466162191","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test3_after_hf01
FROM hive.get_impacted_balances('{"type":"author_reward_operation","value":{"author":"kaylinart","permlink":"should-you-start-a-drop-shipping-business","hbd_payout":{"amount":"9048","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"5790","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"67826998226","precision":6,"nai":"@@000000037"},"curators_vesting_payout":{"amount":"16466162191","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}', TRUE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test4_before_hf01
FROM hive.get_impacted_balances('{"type":"producer_reward_operation","value":{"producer":"initminer","vesting_shares":{"amount":"1000000","precision":6,"nai":"@@000000037"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test4_after_hf01
FROM hive.get_impacted_balances('{"type":"producer_reward_operation","value":{"producer":"initminer","vesting_shares":{"amount":"1000000","precision":6,"nai":"@@000000037"}}}', True) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test5_before_hf01
FROM hive.get_impacted_balances('{"type":"account_create_operation","value":{"fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"creator":"murdock5","new_account_name":"proskynneo","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb",1]]},"memo_key":"STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb","json_metadata":""}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test5_after_hf01
FROM hive.get_impacted_balances('{"type":"account_create_operation","value":{"fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"creator":"murdock5","new_account_name":"proskynneo","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb",1]]},"memo_key":"STM5sj5VtPtXr2UqJES3SGhPocFMTtm2SfTowfBEjNLuG51EUcmGb","json_metadata":""}}', True) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test6_before_hf01
FROM hive.get_impacted_balances('{"type":"curation_reward_operation","value":{"curator":"steemroller","reward":{"amount":"2623363281","precision":6,"nai":"@@000000037"},"comment_author":"brookdemar","comment_permlink":"reflections-from-life-on-the-streets","payout_must_be_claimed":false}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test6_after_hf01
FROM hive.get_impacted_balances('{"type":"curation_reward_operation","value":{"curator":"steemroller","reward":{"amount":"2623363281","precision":6,"nai":"@@000000037"},"comment_author":"brookdemar","comment_permlink":"reflections-from-life-on-the-streets","payout_must_be_claimed":false}}', True) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test7_before_hf01
FROM hive.get_impacted_balances('{"type":"account_created_operation","value":{"new_account_name":"witnesses","creator":"steem","initial_vesting_shares":{"amount":"72763034396","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"220000000000","precision":6,"nai":"@@000000037"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test7_after_hf01
FROM hive.get_impacted_balances('{"type":"account_created_operation","value":{"new_account_name":"witnesses","creator":"steem","initial_vesting_shares":{"amount":"72763034396","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"220000000000","precision":6,"nai":"@@000000037"}}}', TRUE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test8_before_hf01
FROM hive.get_impacted_balances('{"type":"comment_benefactor_reward_operation","value":{"benefactor":"dpoll.curation","author":"sereze","permlink":"which-instrument-would-you-like-to-play","hbd_payout":{"amount":"27","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"2","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"118862104","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test8_after_hf01
FROM hive.get_impacted_balances('{"type":"comment_benefactor_reward_operation","value":{"benefactor":"dpoll.curation","author":"sereze","permlink":"which-instrument-would-you-like-to-play","hbd_payout":{"amount":"27","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"2","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"118862104","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}', TRUE) f
;

ASSERT _pattern0_before_hf01 = _test0_before_hf01, 'Broken impacted balances result in "claim_reward_balance_operation" method before hf01';
ASSERT _pattern0_after_hf01 = _test0_after_hf01, 'Broken impacted balances result in "claim_reward_balance_operation" method after hf01';

ASSERT _pattern1_before_hf01 = _test1_before_hf01, 'Broken impacted balances result in "fill_vesting_withdraw_operation" method before hf01';
ASSERT _pattern1_after_hf01 = _test1_after_hf01, 'Broken impacted balances result in "fill_vesting_withdraw_operation" method after hf01';

ASSERT _pattern2_before_hf01 = _test2_before_hf01, 'Broken impacted balances result in "transfer_to_vesting_completed_operation" method before hf01';
ASSERT _pattern2_after_hf01 = _test2_after_hf01, 'Broken impacted balances result in "transfer_to_vesting_completed_operation" method after hf01';

ASSERT _pattern3_before_hf01 = _test3_before_hf01, 'Broken impacted balances result in "author_reward_operation" method before hf01';
ASSERT _pattern3_after_hf01 = _test3_after_hf01, 'Broken impacted balances result in "author_reward_operation" method after hf01';

ASSERT _pattern4_before_hf01 = _test4_before_hf01, 'Broken impacted balances result in "producer_reward_operation" method before hf01';
ASSERT _pattern4_after_hf01 = _test4_after_hf01, 'Broken impacted balances result in "producer_reward_operation" method after hf01';

ASSERT _pattern5_before_hf01 = _test5_before_hf01, 'Broken impacted balances result in "account_create_operation" method before hf01';
ASSERT _pattern5_after_hf01 = _test5_after_hf01, 'Broken impacted balances result in "account_create_operation" method after hf01';

ASSERT _pattern6_before_hf01 = _test6_before_hf01, 'Broken impacted balances result in "curation_reward_operation" method before hf01';
ASSERT _pattern6_after_hf01 = _test6_after_hf01, 'Broken impacted balances result in "curation_reward_operation" method after hf01';

ASSERT _pattern7_before_hf01 = _test7_before_hf01, 'Broken impacted balances result in "account_created_operation" method before hf01';
ASSERT _pattern7_after_hf01 = _test7_after_hf01, 'Broken impacted balances result in "account_created_operation" method after hf01';

ASSERT _pattern8_before_hf01 = _test8_before_hf01, 'Broken impacted balances result in "comment_benefactor_reward_operation" method before hf01';
ASSERT _pattern8_after_hf01 = _test8_after_hf01, 'Broken impacted balances result in "comment_benefactor_reward_operation" method after hf01';

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


