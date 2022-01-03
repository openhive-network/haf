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
BEGIN

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return) 
INTO _test1
FROM hive.get_impacted_balances('{"type":"escrow_transfer_operation","value":{"from":"gregory.latinier","to":"ekitcho","hbd_amount":{"amount":"1","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},"escrow_id":1,"agent":"fabien","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"{\"terms\":\"test\"}","ratification_deadline":"2018-04-25T19:08:45","escrow_expiration":"2018-04-26T19:08:45"}}') f
;

ASSERT _pattern1 = _test1, 'Broken impacted balances result';

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


