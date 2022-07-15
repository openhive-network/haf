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
  _test1a hive.impacted_balances_return[];
  _test1b hive.impacted_balances_return[];

  _pattern2 hive.impacted_balances_return[] = '{"(cloop1,13573174000000,6,37)","(cloop5,-188000,3,21)"}';
  _test2 hive.impacted_balances_return[];

  _pattern3 hive.impacted_balances_return[] = '{"(cloop1,13573174,6,37)","(cloop5,-188000,3,21)"}';
  _test3 hive.impacted_balances_return[];

BEGIN

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test1a
FROM hive.get_impacted_balances('{"type":"escrow_transfer_operation","value":{"from":"gregory.latinier","to":"ekitcho","hbd_amount":{"amount":"1","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},"escrow_id":1,"agent":"fabien","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"{\"terms\":\"test\"}","ratification_deadline":"2018-04-25T19:08:45","escrow_expiration":"2018-04-26T19:08:45"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test1b
FROM hive.get_impacted_balances('{"type":"escrow_transfer_operation","value":{"from":"gregory.latinier","to":"ekitcho","hbd_amount":{"amount":"1","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},"escrow_id":1,"agent":"fabien","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"{\"terms\":\"test\"}","ratification_deadline":"2018-04-25T19:08:45","escrow_expiration":"2018-04-26T19:08:45"}}', TRUE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test2
FROM hive.get_impacted_balances('{"type":"transfer_to_vesting_completed_operation","value":{"from_account":"cloop5","to_account":"cloop1","hive_vested":{"amount":"188000","precision":3,"nai":"@@000000021"},"vesting_shares_received":{"amount":"13573174","precision":6,"nai":"@@000000037"}}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test3
FROM hive.get_impacted_balances('{"type":"transfer_to_vesting_completed_operation","value":{"from_account":"cloop5","to_account":"cloop1","hive_vested":{"amount":"188000","precision":3,"nai":"@@000000021"},"vesting_shares_received":{"amount":"13573174","precision":6,"nai":"@@000000037"}}}}', TRUE) f
;

ASSERT _pattern1 = _test1a, 'Broken impacted balances result';
ASSERT _pattern1 = _test1b, 'Broken impacted balances result';
ASSERT _pattern2 = _test2,  'Broken impacted balances result';
ASSERT _pattern3 = _test3,  'Broken impacted balances result';

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


