DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
  test0 hive.impacted_balances_return[];
  test1 hive.impacted_balances_return[];
  test2 hive.impacted_balances_return[];
  test3 hive.impacted_balances_return[];
  test4 hive.impacted_balances_return[];
  test5 hive.impacted_balances_return[];
  test6 hive.impacted_balances_return[];
  test7 hive.impacted_balances_return[];
  test8 hive.impacted_balances_return[];
  test9 hive.impacted_balances_return[];
  test10 hive.impacted_balances_return[];
  test11 hive.impacted_balances_return[];
  test12 hive.impacted_balances_return[];
  test13 hive.impacted_balances_return[];
  pattern14 hive.impacted_balances_return[] = '{"(\"\",-1000,3,13)"}';
  test14 hive.impacted_balances_return[];

BEGIN
    ----TEST0: EMPTY JSON BODY IN BODY-OPERATION ARGUMENT----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test0
    FROM hive.get_impacted_balances('{}', FALSE) f
    ;

    ASSERT FALSE, 'TEST0 should throw exception: "invalid_text_representation"';

    exception 
    -- ignore exceptions in test0
        when invalid_text_representation then
            NULL;
    END;

    ----TEST1: EMPTY BODY-OPERATION ARGUMENT----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test1
    FROM hive.get_impacted_balances(''::hive.operation, FALSE) f
    ;

    ASSERT FALSE, 'TEST1 should throw exception: "feature_not_supported"';

    exception 
    -- ignore exceptions in test1
        when feature_not_supported then
            NULL;
    END;

    ----TEST2: INCORRECT BODY-OPERATION ARGUMENT----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test2
    FROM hive.get_impacted_balances('{"type":"not_existing_type","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"xtar","receiver":"someguy123","escrow_id":72526562,"hbd_amount":{"amount":"5000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST2 should throw exception: "invalid_text_representation"';

    exception 
    -- ignore exceptions in test2
        when invalid_text_representation then
            NULL;
    END;

    ----TEST3: INCORRECT TYPE OF hf_01 ARGUMENT----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test3
    FROM hive.get_impacted_balances('{"type":"escrow_release_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"xtar","receiver":"someguy123","escrow_id":72526562,"hbd_amount":{"amount":"5000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"}}}', 100.0) f
    ;

    ASSERT FALSE, 'TEST3 should throw exception: "undefined_function"';

    exception 
    -- ignore exceptions in test3
        when undefined_function then
            NULL;
    END;

    ----TEST4: INCORRECT TYPE OF BODY-OPERATION ARGUMENT----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test4
    FROM hive.get_impacted_balances(100, FALSE) f
    ;

    ASSERT FALSE, 'TEST4 should throw exception: "undefined_function"';

    exception 
    -- ignore exceptions in test4
        when undefined_function then
            NULL;
    END;

    ----TEST5: ARRAY IN BODY-OPERATION ARGUMENT--------
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test5
    FROM hive.get_impacted_balances('[1,3,34,543,34]', FALSE) f
    ;

    ASSERT FALSE, 'TEST5 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test5
        when invalid_text_representation then
            NULL;
    END;

    ----TEST6: BROKEN DATA IN BODY-OPERATION ARGUMENT (missing "type" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test6
    FROM hive.get_impacted_balances('{"value":{"owner":"summon","requestid":1467592156,"amount":{"amount":"5000","precision":3,"nai":"@@000000013"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST6 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test6
        when invalid_text_representation then
            NULL;
    END;

    ----TEST7: BROKEN DATA IN BODY-OPERATION ARGUMENT (missing "amount" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test7
    FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"precision":3,"nai":"@@000000013"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST7 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test7
        when invalid_text_representation then
            NULL;
    END;

    ----TEST8 BROKEN DATA IN BODY-OPERATION ARGUMENT (missing "precision" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test8
    FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"amount":"5000","nai":"@@000000013"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST8 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test8
        when invalid_text_representation then
            NULL;
    END;

    ----TEST9: BROKEN DATA IN BODY-OPERATION ARGUMENT (missing "nai" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test9
    FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"amount":"5000","precision":3}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST9 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test9
        when invalid_text_representation then
            NULL;
    END;

    ----TEST10: BROKEN DATA IN BODY-OPERATION ARGUMENT (broken "amount" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test10
    FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"amount":5000,"precision":3,"nai":"@@000000013"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST10 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test10
        when invalid_text_representation then
            NULL;
    END;

    ----TEST11: BROKEN DATA IN BODY-OPERATION ARGUMENT (broken "precision" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test11
    FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"amount":"5000","precision":"some_string","nai":"@@000000013"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST11 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test11
        when invalid_text_representation then
            NULL;
    END;

    ----TEST12: BROKEN DATA IN BODY-OPERATION ARGUMENT (broken "nai" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test12
    FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"amount":"5000","precision":3,"nai":"@@000000099"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST12 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test12
        when invalid_text_representation then
            NULL;
    END;

    ----TEST13: BROKEN DATA IN BODY-OPERATION ARGUMENT (broken "amount" field) ----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test13
    FROM hive.get_impacted_balances('{"type":"convert_operation","value":{"owner":"summon","requestid":1467592156,"amount":{"amount":"some_string","precision":3,"nai":"@@000000013"}}}', FALSE) f
    ;

    ASSERT FALSE, 'TEST13 should throw exception: "invalid_text_representation"';

    exception
    -- ignore exceptions in test13
        when invalid_text_representation then
            NULL;
    END;

    ----TEST14: LEAK OF ACCOUNT NAME FIELD IN BODY-OPERATION ARGUMENT----
    BEGIN
    SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
    INTO test14
    FROM hive.get_impacted_balances('{"type":"transfer_to_savings_operation","value":{"amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}', FALSE) f
    ;

    ASSERT pattern14 = test14, 'Broken impacted balances result in TEST14';
    END;
END;
$BODY$
;



