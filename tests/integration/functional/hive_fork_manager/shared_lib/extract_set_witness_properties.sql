DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TABLE samples( TEXT pname, TEXT pvalue, hive.extract_set_witness_properties_return pattern );
    INSERT INTO samples(pname, pvalue, pattern) VALUES
    ('account_creation_fee', 'b80b00000000000003535445454d0000')
    ('account_subsidy_budget', '1d030000')
    ('account_subsidy_decay', 'b94c0500')
    ('hbd_interest_rate', 'dc05')
    ('key', '02d912ebc6358fe5b7d86964b9714b5e4d04c2d537c6f6305a2cdfcc22a0b0dc47')
    ('maximum_block_size', '00000100')
    ('new_signing_key', '000000000000000000000000000000000000000000000000000000000000000000')
    ('url', '5b68747470733a2f2f7065616b642e636f6d2f686976652d3131313131312f4073686d6f6f676c656f73756b616d692f68656c702d737570706f72742d636869736465616c6864732d686976652d7769746e6573732d736572766572')
    ;
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


