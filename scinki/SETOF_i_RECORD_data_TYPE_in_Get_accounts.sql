
do scinki.txt powinno isc

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __temp_text_array TEXT[];
    __temp_text TEXT;

    temprow RECORD;

BEGIN

    __temp_text := hive.get_impacted_accounts('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}') LIMIT 1;

    raise notice '__temp_text => %', __temp_text;

    select * into __temp_text from hive.get_impacted_accounts('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}');

    raise notice '__temp_text => %', __temp_text;

    raise notice '__temp_text => %', __temp_text;


    FOR temprow IN
        SELECT * FROM hive.get_impacted_accounts('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}') 
        
    LOOP
        raise notice 'temprow ---> %', temprow;
        __temp_text := temprow;
        raise notice '__temp_text ---> %', __temp_text;
    END LOOP;


     raise warning 'SELECT pg_typeof(temprow) +> %', pg_typeof(temprow);



    

    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}') ) = 2, 'Incorrect number of impacted accounts';
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{"type":"escrow_transfer_operation","value":{"from":"xtar","to":"testz","hbd_amount":{"amount":"0","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"1","precision":3,"nai":"@@000000021"},"escrow_id":123456,"agent":"fabien","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"","ratification_deadline":"2017-02-15T15:15:11","escrow_expiration":"2017-02-16T15:15:11"}}') ) = 3, 'Incorrect number of impacted accounts';

    --false tests
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{}') ) = 0, 'Incorrect number of impacted accounts';
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('') ) = 0, 'Incorrect number of impacted accounts';
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{BANANA}') ) = 0, 'Incorrect number of impacted accounts';
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{') ) = 0, 'Incorrect number of impacted accounts';
    ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('KIWI') ) = 0, 'Incorrect number of impacted accounts';

END;
$BODY$
;

