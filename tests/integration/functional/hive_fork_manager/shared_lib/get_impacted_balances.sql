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
  _pattern1 hive.impacted_balances_return[] = '{"(gregory.latinier,-1,3,21)","(gregory.latinier,-1,3,13)"}';
  _test1 hive.impacted_balances_return[];

  _pattern2 hive.impacted_balances_return[] = '{"(anna.art.time,27094,3,21)","(anna.art.time,-55576922199,6,37)"}';
  _test2 hive.impacted_balances_return[];

  _pattern3 hive.impacted_balances_return[] = '{"(anyx,389734346,6,37)"}';
  _test3 hive.impacted_balances_return[];

  _pattern4 hive.impacted_balances_return[] = '{"(oracle-d,0,3,21)","(null,0,3,21)"}';
  _test4 hive.impacted_balances_return[];

  _pattern5 hive.impacted_balances_return[] = '{"(hello,0,3,21)","(null,0,3,21)"}';
  _test5 hive.impacted_balances_return[];

  _pattern6 hive.impacted_balances_return[] = '{"(ocrdu,17,3,21)","(ocrdu,11,3,13)","(ocrdu,185025103,6,37)"}';
  _test6 hive.impacted_balances_return[];

  _pattern7 hive.impacted_balances_return[] = '{"(admin,-833000,3,21)","(steemit,833000,3,21)"}';
  _test7 hive.impacted_balances_return[];

  _pattern8 hive.impacted_balances_return[] = '{"(siol,-1100,3,13)"}';
  _test8 hive.impacted_balances_return[];

  _pattern9 hive.impacted_balances_return[] = '{"(abit,-1000,3,13)"}';
  _test9 hive.impacted_balances_return[];

  _pattern10 hive.impacted_balances_return[] = '{"(dez1337,-1,3,13)"}';
  _test10 hive.impacted_balances_return[];

  _pattern11 hive.impacted_balances_return[] = '{"(steem,-35000,3,21)","(null,35000,3,21)"}';
  _test11 hive.impacted_balances_return[];

  _pattern12 hive.impacted_balances_return[] = '{"(linouxis9,-9950,3,21)"}';
  _test12 hive.impacted_balances_return[];

  _pattern13 hive.impacted_balances_return[] = '{"(aellly,3007,3,13)","(steem.dao,-3007,3,13)"}';
  _test13 hive.impacted_balances_return[];

  _pattern14 hive.impacted_balances_return[] = '{"(rishi556,1000,3,21)","(deathwing,-1000,3,21)"}';
  _test14 hive.impacted_balances_return[];

--    _pattern15 hive.impacted_balances_return[] = ''; --This method return nothing
--    _test15 hive.impacted_balances_return[];

  _pattern16 hive.impacted_balances_return[] = '{"(linouxis9,9950,3,21)"}';
  _test16 hive.impacted_balances_return[];

  _pattern17 hive.impacted_balances_return[] = '{"(nextgencrypto,6105,3,13)","(abit,33000,3,21)"}';
  _test17 hive.impacted_balances_return[];

--    _pattern18 hive.impacted_balances_return[] = ''; --This method return nothing
--    _test18 hive.impacted_balances_return[];

  _pattern19 hive.impacted_balances_return[] = '{"(initminer,0,3,21)"}';
  _test19 hive.impacted_balances_return[];

  _pattern20 hive.impacted_balances_return[] = '{"(faddy,357000000,6,37)","(faddy,-357000,3,21)"}';
  _test20 hive.impacted_balances_return[];

  _pattern21 hive.impacted_balances_return[] = '{"(randaletouri,710,3,21)","(randaletouri,-26475,6,37)"}';
  _test21 hive.impacted_balances_return[];

  _pattern22 hive.impacted_balances_return[] = '{"(summon,18867,3,21)"}';
  _test22 hive.impacted_balances_return[];

  _pattern23 hive.impacted_balances_return[] = '{"(adm,1200000,3,21)"}';
  _test23 hive.impacted_balances_return[];

  _pattern24 hive.impacted_balances_return[] = '{"(gandalf,647,3,21)"}';
  _test24 hive.impacted_balances_return[];

  _pattern25 hive.impacted_balances_return[] = '{"(hive.fund,-41676736,3,21)","(hive.fund,6543247,3,13)"}';
  _test25 hive.impacted_balances_return[];

  _pattern26 hive.impacted_balances_return[] = '{"(steem.dao,157,3,13)","(steem.dao,-157,3,13)"}';
  _test26 hive.impacted_balances_return[];
  
BEGIN

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test1
FROM hive.get_impacted_balances('{"type":"escrow_transfer_operation","value":{"from":"gregory.latinier","to":"ekitcho","hbd_amount":{"amount":"1","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},"escrow_id":1,"agent":"fabien","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"{\"terms\":\"test\"}","ratification_deadline":"2018-04-25T19:08:45","escrow_expiration":"2018-04-26T19:08:45"}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test2
FROM hive.get_impacted_balances('{"type":"fill_vesting_withdraw_operation","value":{"from_account":"anna.art.time","to_account":"anna.art.time","withdrawn":{"amount":"55576922199","precision":6,"nai":"@@000000037"},"deposited":{"amount":"27094","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test3
FROM hive.get_impacted_balances('{"type":"producer_reward_operation","value":{"producer":"anyx","vesting_shares":{"amount":"389734346","precision":6,"nai":"@@000000037"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test4
FROM hive.get_impacted_balances('{"type":"claim_account_operation","value":{"creator":"oracle-d","fee":{"amount":"0","precision":3,"nai":"@@000000021"},"extensions":[]}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test5
FROM hive.get_impacted_balances('{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"hello","new_account_name":"fabian","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8MN3FNBa8WbEpxz3wGL3L1mkt6sGnncH8iuto7r8Wa3T9NSSGT",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8HCf7QLUexogEviN8x1SpKRhFwg2sc8LrWuJqv7QsmWrua6ZyR",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8EhGWcEuQ2pqCKkGHnbmcTNpWYZDjGTT7ketVBp4gUStDr2brz",1]]},"memo_key":"STM6Gkj27XMkoGsr4zwEvkjNhh4dykbXmPFzHhT8g86jWsqu3U38X","json_metadata":"{}"}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test6
FROM hive.get_impacted_balances('{"type":"claim_reward_balance_operation","value":{"account":"ocrdu","reward_hive":{"amount":"17","precision":3,"nai":"@@000000021"},"reward_hbd":{"amount":"11","precision":3,"nai":"@@000000013"},"reward_vests":{"amount":"185025103","precision":6,"nai":"@@000000037"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test7
FROM hive.get_impacted_balances('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test8
FROM hive.get_impacted_balances('{"type":"escrow_transfer_operation","value":{"from":"siol","to":"james","hbd_amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},"escrow_id":23456789,"agent":"fabien","fee":{"amount":"100","precision":3,"nai":"@@000000013"},"json_meta":"{}","ratification_deadline":"2017-02-26T11:22:39","escrow_expiration":"2017-02-28T11:22:39"}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test9
FROM hive.get_impacted_balances('{"type":"transfer_to_savings_operation","value":{"from":"abit","to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test10
FROM hive.get_impacted_balances('{"type":"limit_order_create2_operation","value":{"owner":"dez1337","orderid":492991,"amount_to_sell":{"amount":"1","precision":3,"nai":"@@000000013"},"exchange_rate":{"base":{"amount":"1","precision":3,"nai":"@@000000013"},"quote":{"amount":"10","precision":3,"nai":"@@000000021"}},"fill_or_kill":false,"expiration":"2017-05-12T23:11:13"}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test11
FROM hive.get_impacted_balances('{"type":"account_create_with_delegation_operation","value":{"fee":{"amount":"35000","precision":3,"nai":"@@000000021"},"delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"steem","new_account_name":"hendratayogas","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM51YSoy7MdrAWgeTsQo4xYVR7L4BKucjqDPefsB7ZojBZgU7CCN",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5jgwX1VPT4oZpescjwTmf6k8T8oYmg3RrhjaDnSapis9sFojAL",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5BcLMqLSBXa3DX7ThbbDYFEwcHbvUYWoF8PgTaSVAdNUikBQK1",1]]},"memo_key":"STM5Fj3bNfLCvhFC6U67kfNCg6d8CfpxW2AJRJ9KhELEaoBMK9Ltf","json_metadata":"","extensions":[]}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test12
FROM hive.get_impacted_balances('{"type":"limit_order_create_operation","value":{"owner":"linouxis9","orderid":10,"amount_to_sell":{"amount":"9950","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"3500","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2035-10-29T06:32:22"}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test13
FROM hive.get_impacted_balances('{"type":"hardfork_hive_restore_operation","value":{"account":"aellly","treasury":"steem.dao","hbd_transferred":{"amount":"3007","precision":3,"nai":"@@000000013"},"hive_transferred":{"amount":"0","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test14
FROM hive.get_impacted_balances('{"type":"fill_recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","remaining_executions":4}}') f
;

-- SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) --This method return nothing
-- INTO _test15
-- FROM hive.get_impacted_balances('{"type":"recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","recurrence":24,"executions":5,"extensions":[]}}') f
-- ;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test16
FROM hive.get_impacted_balances('{"type":"limit_order_cancelled_operation","value":{"seller":"linouxis9","amount_back":{"amount":"9950","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test17
FROM hive.get_impacted_balances('{"type":"fill_order_operation","value":{"current_owner":"abit","current_orderid":42896,"current_pays":{"amount":"6105","precision":3,"nai":"@@000000013"},"open_owner":"nextgencrypto","open_orderid":1467589030,"open_pays":{"amount":"33000","precision":3,"nai":"@@000000021"}}}') f
;

-- SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)  --This method return nothing
-- INTO _test18
-- FROM hive.get_impacted_balances('{"type":"failed_recurrent_transfer_operation","value":{"from":"blackknight1423","to":"aa111","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"","consecutive_failures":1,"remaining_executions":0,"deleted":false}}') f
-- ;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test19
FROM hive.get_impacted_balances('{"type":"pow_reward_operation","value":{"worker":"initminer","reward":{"amount":"0","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test20
FROM hive.get_impacted_balances('{"type":"transfer_to_vesting_completed_operation","value":{"from_account":"faddy","to_account":"faddy","hive_vested":{"amount":"357000","precision":3,"nai":"@@000000021"},"vesting_shares_received":{"amount":"357000000","precision":6,"nai":"@@000000037"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test21
FROM hive.get_impacted_balances('{"type":"fill_vesting_withdraw_operation","value":{"from_account":"randaletouri","to_account":"randaletouri","withdrawn":{"amount":"26475","precision":6,"nai":"@@000000037"},"deposited":{"amount":"710","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test22
FROM hive.get_impacted_balances('{"type":"fill_convert_request_operation","value":{"owner":"summon","requestid":1467592156,"amount_in":{"amount":"5000","precision":3,"nai":"@@000000013"},"amount_out":{"amount":"18867","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test23
FROM hive.get_impacted_balances('{"type":"liquidity_reward_operation","value":{"owner":"adm","payout":{"amount":"1200000","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test24
FROM hive.get_impacted_balances('{"type":"fill_collateralized_convert_request_operation","value":{"owner":"gandalf","requestid":1625061900,"amount_in":{"amount":"353","precision":3,"nai":"@@000000021"},"amount_out":{"amount":"103","precision":3,"nai":"@@000000013"},"excess_collateral":{"amount":"647","precision":3,"nai":"@@000000021"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test25
FROM hive.get_impacted_balances('{"type":"sps_convert_operation","value":{"fund_account":"hive.fund","hive_amount_in":{"amount":"41676736","precision":3,"nai":"@@000000021"},"hbd_amount_out":{"amount":"6543247","precision":3,"nai":"@@000000013"}}}') f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test26
FROM hive.get_impacted_balances('{"type":"proposal_pay_operation","value":{"proposal_id":0,"receiver":"steem.dao","payer":"steem.dao","payment":{"amount":"157","precision":3,"nai":"@@000000013"},"trx_id":"0000000000000000000000000000000000000000","op_in_trx":37184}}') f
;


ASSERT _pattern1 = _test1, 'Broken impacted balances result in "escrow_transfer_operation" method';
ASSERT _pattern2 = _test2, 'Broken impacted balances result in "fill_vesting_withdraw_operation" method';
ASSERT _pattern3 = _test3, 'Broken impacted balances result in "producer_reward_operation" method';
ASSERT _pattern4 = _test4, 'Broken impacted balances result in "claim_account_operation" method';
ASSERT _pattern5 = _test5, 'Broken impacted balances result in "account_create_operation" method';
ASSERT _pattern6 = _test6, 'Broken impacted balances result in "claim_reward_balance_operation" method';
ASSERT _pattern7 = _test7, 'Broken impacted balances result in "transfer_operation" method';
ASSERT _pattern8 = _test8, 'Broken impacted balances result in "escrow_transfer_operation" method';
ASSERT _pattern9 = _test9, 'Broken impacted balances result in "transfer_to_savings_operation" method';
ASSERT _pattern10 = _test10, 'Broken impacted balances result in "limit_order_create2_operation" method';
ASSERT _pattern11 = _test11, 'Broken impacted balances result in "account_create_with_delegation_operation" method';
ASSERT _pattern12 = _test12, 'Broken impacted balances result in "limit_order_create_operation" method';
ASSERT _pattern13 = _test13, 'Broken impacted balances result in "hardfork_hive_restore_operation" method';
ASSERT _pattern14 = _test14, 'Broken impacted balances result in "fill_recurrent_transfer_operation" method';
-- ASSERT _pattern15 = _test15, 'Broken impacted balances result in "recurrent_transfer_operation" method'; --This method return nothing
ASSERT _pattern16 = _test16, 'Broken impacted balances result in "limit_order_cancelled_operation" method';
ASSERT _pattern17 = _test17, 'Broken impacted balances result in "fill_order_operation" method';
-- ASSERT _pattern18 = _test18, 'Broken impacted balances result in "failed_recurrent_transfer_operation" method'; --This method return nothing
ASSERT _pattern19 = _test19, 'Broken impacted balances result in "pow_reward_operation" method';
ASSERT _pattern20 = _test20, 'Broken impacted balances result in "transfer_to_vesting_completed_operation" method';
ASSERT _pattern21 = _test21, 'Broken impacted balances result in "fill_vesting_withdraw_operation" method';
ASSERT _pattern22 = _test22, 'Broken impacted balances result in "fill_convert_request_operation" method';
ASSERT _pattern23 = _test23, 'Broken impacted balances result in "liquidity_reward_operation" method';
ASSERT _pattern24 = _test24, 'Broken impacted balances result in "fill_collateralized_convert_request_operation" method';
ASSERT _pattern25 = _test25, 'Broken impacted balances result in "sps_convert_operation" method';
ASSERT _pattern26 = _test26, 'Broken impacted balances result in "proposal_pay_operation" method';


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
