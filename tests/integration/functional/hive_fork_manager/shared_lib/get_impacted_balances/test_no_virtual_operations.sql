DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
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

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
  _pattern0 hive.impacted_balances_return[] = '{"(admin,-833000,3,21)","(steemit,833000,3,21)"}';
  _test0 hive.impacted_balances_return[];

  _pattern1 hive.impacted_balances_return[] = '{"(linouxis9,-9950,3,21)"}';
  _test1 hive.impacted_balances_return[];

  _pattern2 hive.impacted_balances_return[] = '{"(summon,-5000,3,13)"}';
  _test2 hive.impacted_balances_return[];

  _pattern3 hive.impacted_balances_return[] = '{"(dez1337,-1,3,13)"}';
  _test3 hive.impacted_balances_return[];

  _pattern4 hive.impacted_balances_return[] = '{"(hightouch,-2,3,21)","(hightouch,-1,3,13)"}';
  _test4 hive.impacted_balances_return[];

  _pattern5 hive.impacted_balances_return[] = '{"(someguy123,5000,3,13)"}';
  _test5 hive.impacted_balances_return[];

  _pattern6 hive.impacted_balances_return[] = '{"(abit,-1000,3,13)"}';
  _test6 hive.impacted_balances_return[];

  _pattern7 hive.impacted_balances_return[] = '{"(gandalf,-1000,3,21)"}';
  _test7 hive.impacted_balances_return[];

  _pattern8 hive.impacted_balances_return[] = '{"(steem,-35000,3,21)","(null,35000,3,21)"}';
  _test8 hive.impacted_balances_return[];

  _pattern9 hive.impacted_balances_return[] = '{"(almost-digital,-3000,3,21)","(null,3000,3,21)"}';
  _test9 hive.impacted_balances_return[];

BEGIN

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test0
FROM hive.get_impacted_balances('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test1
FROM hive.get_impacted_balances('{"type":"limit_order_create_operation","value":{"owner":"linouxis9","orderid":10,"amount_to_sell":{"amount":"9950","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"3500","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2035-10-29T06:32:22"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test2
FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"amount":"5000","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test3
FROM hive.get_impacted_balances('{"type":"limit_order_create2_operation","value":{"owner":"dez1337","orderid":492991,"amount_to_sell":{"amount":"1","precision":3,"nai":"@@000000013"},"exchange_rate":{"base":{"amount":"1","precision":3,"nai":"@@000000013"},"quote":{"amount":"10","precision":3,"nai":"@@000000021"}},"fill_or_kill":false,"expiration":"2017-05-12T23:11:13"}}', FALSE) f
;
SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test4
FROM hive.get_impacted_balances('{"type":"escrow_transfer_operation","value":{"from":"hightouch","to":"fundition.help","hbd_amount":{"amount":"1","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"1","precision":3,"nai":"@@000000021"},"escrow_id":1,"agent":"ongame","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"47700","ratification_deadline":"2018-11-06T04:05:33","escrow_expiration":"2018-11-07T04:05:33"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test5
FROM hive.get_impacted_balances('{"type":"escrow_release_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"xtar","receiver":"someguy123","escrow_id":72526562,"hbd_amount":{"amount":"5000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test6
FROM hive.get_impacted_balances('{"type":"transfer_to_savings_operation","value":{"from":"abit","to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test7
FROM hive.get_impacted_balances('{"type":"collateralized_convert_operation","value":{"owner":"gandalf","requestid":1625061900,"amount":{"amount":"1000","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test8
FROM hive.get_impacted_balances('{"type":"account_create_with_delegation_operation","value":{"fee":{"amount":"35000","precision":3,"nai":"@@000000021"},"delegation":{"amount":"220000000000","precision":6,"nai":"@@000000037"},"creator":"steem","new_account_name":"witnesses","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5YzwCee4R8Dxoj5SSnweGLLYA4qkZ9AQ8XxufRG2e3s5PWAkYD",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5hVs7ySn21sYrYmKUhukvo2myqKjiF8oHUau8dhMDGYqFNpJbJ",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM89mZqrtnvrj3rsiPiUM34Zj1cNjaYzvSgQsmpa9rUXHPrdPrFL",1]]},"memo_key":"STM7gVcCwYM6UyhZaGRcpbpZi5rvKu79bS1AWaeBeBH5cevMbG7TA","json_metadata":"","extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test9
FROM hive.get_impacted_balances('{"type":"claim_account_operation","value":{"creator":"almost-digital","fee":{"amount":"3000","precision":3,"nai":"@@000000021"},"extensions":[]}}', FALSE) f
;

ASSERT _pattern0 = _test0, 'Broken impacted balances result in "transfer_operation" method';
ASSERT _pattern1 = _test1, 'Broken impacted balances result in "limit_order_create_operation" method';
ASSERT _pattern2 = _test2, 'Broken impacted balances result in "convert_operation" method';
ASSERT _pattern3 = _test3, 'Broken impacted balances result in "limit_order_create2_operation" method';
ASSERT _pattern4 = _test4, 'Broken impacted balances result in "escrow_transfer_operation" method';
ASSERT _pattern5 = _test5, 'Broken impacted balances result in "escrow_release_operation" method';
ASSERT _pattern6 = _test6, 'Broken impacted balances result in "transfer_to_savings_operation" method';
ASSERT _pattern7 = _test7, 'Broken impacted balances result in "collateralized_convert_operation" method';
ASSERT _pattern8 = _test8, 'Broken impacted balances result in "account_create_with_delegation_operation" method';
ASSERT _pattern9 = _test9, 'Broken impacted balances result in "claim_account_operation" method';



END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
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


