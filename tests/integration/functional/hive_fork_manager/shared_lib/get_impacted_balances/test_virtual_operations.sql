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
  _pattern0 hive.impacted_balances_return[] = '{"(summon,18867,3,21)"}';
  _test0 hive.impacted_balances_return[];

  _pattern1 hive.impacted_balances_return[] = '{"(twinner,46255376000000,6,37)"}';
  _test1 hive.impacted_balances_return[];

  _pattern2 hive.impacted_balances_return[] = '{"(adm,1200000,3,21)"}';
  _test2 hive.impacted_balances_return[];

  _pattern3 hive.impacted_balances_return[] = '{"(hisnameisolllie,1,3,13)"}';
  _test3 hive.impacted_balances_return[];

  _pattern4 hive.impacted_balances_return[] = '{"(nextgencrypto,6105,3,13)","(abit,33000,3,21)"}';
  _test4 hive.impacted_balances_return[];

  _pattern5 hive.impacted_balances_return[] = '{"(abit,1000,3,13)"}';
  _test5 hive.impacted_balances_return[];

  _pattern6 hive.impacted_balances_return[] = '{"(steem.dao,157,3,13)","(steem.dao,-157,3,13)"}';
  _test6 hive.impacted_balances_return[];

  _pattern7 hive.impacted_balances_return[] = '{"(steem.dao,60,3,13)"}';
  _test7 hive.impacted_balances_return[];

  _pattern8 hive.impacted_balances_return[] = '{"(aellly,3007,3,13)","(steem.dao,-3007,3,13)"}';
  _test8 hive.impacted_balances_return[];

  _pattern9 hive.impacted_balances_return[] = '{"(hive.fund,83353473585,3,21)","(hive.fund,560371025,3,13)"}';
  _test9 hive.impacted_balances_return[];

  _pattern10 hive.impacted_balances_return[] = '{"(hive.fund,-41676736,3,21)","(hive.fund,6543247,3,13)"}';
  _test10 hive.impacted_balances_return[];

  _pattern11 hive.impacted_balances_return[] = '{"(gandalf,647,3,21)"}';
  _test11 hive.impacted_balances_return[];

  _pattern12 hive.impacted_balances_return[] = '{"(rishi556,1000,3,21)","(deathwing,-1000,3,21)"}';
  _test12 hive.impacted_balances_return[];

  _pattern13 hive.impacted_balances_return[] = '{"(linouxis9,9950,3,21)"}';
  _test13 hive.impacted_balances_return[];

  _pattern14 hive.impacted_balances_return[] = '{"(gtg,-10000,3,13)","(steem.dao,10000,3,13)"}';
  _test14 hive.impacted_balances_return[];

  _pattern15 hive.impacted_balances_return[] = '{"(gandalf,103,3,13)"}';
  _test15 hive.impacted_balances_return[];

  _pattern16 hive.impacted_balances_return[] = '{"(xtar,1,3,13)"}';
  _test16 hive.impacted_balances_return[];

  _pattern17 hive.impacted_balances_return[] = '{"(xtar,1,3,21)","(xtar,1,3,21)"}';
  _test17 hive.impacted_balances_return[];

BEGIN

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test0
FROM hive.get_impacted_balances('{"type":"fill_convert_request_operation","value":{"owner":"summon","requestid":1467592156,"amount_in":{"amount":"5000","precision":3,"nai":"@@000000013"},"amount_out":{"amount":"18867","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test1
FROM hive.get_impacted_balances('{"type":"curation_reward_operation","value":{"curator":"twinner","reward":{"amount":"46255376","precision":6,"nai":"@@000000037"},"comment_author":"magetanbonar","comment_permlink":"warum-freiheit-wichtiger-als-gleichheit-ist","payout_must_be_claimed":false}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test2
FROM hive.get_impacted_balances('{"type":"liquidity_reward_operation","value":{"owner":"adm","payout":{"amount":"1200000","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test3
FROM hive.get_impacted_balances('{"type":"interest_operation","value":{"owner":"hisnameisolllie","interest":{"amount":"1","precision":3,"nai":"@@000000013"},"is_saved_into_hbd_balance":true}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test4
FROM hive.get_impacted_balances('{"type":"fill_order_operation","value":{"current_owner":"abit","current_orderid":42896,"current_pays":{"amount":"6105","precision":3,"nai":"@@000000013"},"open_owner":"nextgencrypto","open_orderid":1467589030,"open_pays":{"amount":"33000","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test5
FROM hive.get_impacted_balances('{"type":"fill_transfer_from_savings_operation","value":{"from":"abit","to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"request_id":101,"memo":""}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test6
FROM hive.get_impacted_balances('{"type":"proposal_pay_operation","value":{"proposal_id":0,"receiver":"steem.dao","payer":"steem.dao","payment":{"amount":"157","precision":3,"nai":"@@000000013"},"trx_id":"0000000000000000000000000000000000000000","op_in_trx":40683}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test7
FROM hive.get_impacted_balances('{"type":"dhf_funding_operation","value":{"treasury":"steem.dao","additional_funds":{"amount":"60","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test8
FROM hive.get_impacted_balances('{"type":"hardfork_hive_restore_operation","value":{"account":"aellly","treasury":"steem.dao","hbd_transferred":{"amount":"3007","precision":3,"nai":"@@000000013"},"hive_transferred":{"amount":"0","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test9
FROM hive.get_impacted_balances('{"type":"consolidate_treasury_balance_operation","value":{"total_moved":[{"amount":"83353473585","precision":3,"nai":"@@000000021"},{"amount":"560371025","precision":3,"nai":"@@000000013"}]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test10
FROM hive.get_impacted_balances('{"type":"dhf_conversion_operation","value":{"treasury":"hive.fund","hive_amount_in":{"amount":"41676736","precision":3,"nai":"@@000000021"},"hbd_amount_out":{"amount":"6543247","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test11
FROM hive.get_impacted_balances('{"type":"fill_collateralized_convert_request_operation","value":{"owner":"gandalf","requestid":1625061900,"amount_in":{"amount":"353","precision":3,"nai":"@@000000021"},"amount_out":{"amount":"103","precision":3,"nai":"@@000000013"},"excess_collateral":{"amount":"647","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test12
FROM hive.get_impacted_balances('{"type":"fill_recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","remaining_executions":4}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test13
FROM hive.get_impacted_balances('{"type":"limit_order_cancelled_operation","value":{"seller":"linouxis9","amount_back":{"amount":"9950","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test14
FROM hive.get_impacted_balances('{"type":"proposal_fee_operation","value":{"creator":"gtg","treasury":"steem.dao","proposal_id":0,"fee":{"amount":"10000","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test15
FROM hive.get_impacted_balances('{"type":"collateralized_convert_immediate_conversion_operation","value":{"owner":"gandalf","requestid":1625061900,"hbd_out":{"amount":"103","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test16
FROM hive.get_impacted_balances('{"type":"escrow_approved_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","escrow_id":72526562,"fee":{"amount":"1","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test17
FROM hive.get_impacted_balances('{"type":"escrow_rejected_operation","value":{"from":"xtar","to":"testz","agent":"fabien","escrow_id":123456,"hbd_amount":{"amount":"0","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"1","precision":3,"nai":"@@000000021"},"fee":{"amount":"1","precision":3,"nai":"@@000000021"}}}', FALSE) f
;


ASSERT _pattern0 = _test0, 'Broken impacted balances result in "fill_convert_request_operation" method';
ASSERT _pattern1 = _test1, 'Broken impacted balances result in "curation_reward_operation" method';
ASSERT _pattern2 = _test2, 'Broken impacted balances result in "liquidity_reward_operation" method';
ASSERT _pattern3 = _test3, 'Broken impacted balances result in "interest_operation" method';
ASSERT _pattern4 = _test4, 'Broken impacted balances result in "fill_order_operation" method';
ASSERT _pattern5 = _test5, 'Broken impacted balances result in "fill_transfer_from_savings_operation" method';
ASSERT _pattern6 = _test6, 'Broken impacted balances result in "proposal_pay_operation" method';
ASSERT _pattern7 = _test7, 'Broken impacted balances result in "dhf_funding_operation" method';
ASSERT _pattern8 = _test8, 'Broken impacted balances result in "hardfork_hive_restore_operation" method';
ASSERT _pattern9 = _test9, 'Broken impacted balances result in "consolidate_treasury_balance_operation" method';
ASSERT _pattern10 = _test10, 'Broken impacted balances result in "dhf_conversion_operation" method';
ASSERT _pattern11 = _test11, 'Broken impacted balances result in "fill_collateralized_convert_request_operation" method';
ASSERT _pattern12 = _test12, 'Broken impacted balances result in "fill_recurrent_transfer_operation" method';
ASSERT _pattern13 = _test13, 'Broken impacted balances result in "limit_order_cancelled_operation" method';
ASSERT _pattern14 = _test14, 'Broken impacted balances result in "proposal_fee_operation" method';
ASSERT _pattern15 = _test15, 'Broken impacted balances result in "collateralized_convert_immediate_conversion_operation" method';
ASSERT _pattern16 = _test16, 'Broken impacted balances result in "escrow_approved_operation" method';
ASSERT _pattern17 = _test17, 'Broken impacted balances result in "escrow_rejected_operation" method';

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


