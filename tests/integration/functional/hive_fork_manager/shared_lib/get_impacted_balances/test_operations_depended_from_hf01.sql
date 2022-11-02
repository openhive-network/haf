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

  _pattern3_before_hf01 hive.impacted_balances_return[] = '{"(lat-nayar,245313,3,13)","(lat-nayar,5837051040640000000,6,37)"}';
  _test3_before_hf01 hive.impacted_balances_return[];

  _pattern3_after_hf01 hive.impacted_balances_return[] = '{"(lat-nayar,245313,3,13)","(lat-nayar,5837051040640,6,37)"}';
  _test3_after_hf01 hive.impacted_balances_return[];

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
FROM hive.get_impacted_balances('{"type":"author_reward_operation","value":{"author":"lat-nayar","permlink":"hello-i-am-lat","hbd_payout":{"amount":"245313","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"0","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"5837051040640","precision":6,"nai":"@@000000037"},"curators_vesting_payout":{"amount":"11673992151706","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test3_after_hf01
FROM hive.get_impacted_balances('{"type":"author_reward_operation","value":{"author":"lat-nayar","permlink":"hello-i-am-lat","hbd_payout":{"amount":"245313","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"0","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"5837051040640","precision":6,"nai":"@@000000037"},"curators_vesting_payout":{"amount":"11673992151706","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}', TRUE) f
;

ASSERT _pattern0_before_hf01 = _test0_before_hf01, 'Broken impacted balances result in "claim_reward_balance_operation" method before hf01';
ASSERT _pattern0_after_hf01 = _test0_after_hf01, 'Broken impacted balances result in "claim_reward_balance_operation" method after hf01';

ASSERT _pattern1_before_hf01 = _test1_before_hf01, 'Broken impacted balances result in "fill_vesting_withdraw_operation" method method before hf01';
ASSERT _pattern1_after_hf01 = _test1_after_hf01, 'Broken impacted balances result in "fill_vesting_withdraw_operation" method method after hf01';

ASSERT _pattern2_before_hf01 = _test2_before_hf01, 'Broken impacted balances result in "transfer_to_vesting_completed_operation" method method before hf01';
ASSERT _pattern2_after_hf01 = _test2_after_hf01, 'Broken impacted balances result in "transfer_to_vesting_completed_operation" method method after hf01';

ASSERT _pattern3_before_hf01 = _test3_before_hf01, 'Broken impacted balances result in "author_reward_operation" method method before hf01';
ASSERT _pattern3_after_hf01 = _test3_after_hf01, 'Broken impacted balances result in "author_reward_operation" method method after hf01';

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


