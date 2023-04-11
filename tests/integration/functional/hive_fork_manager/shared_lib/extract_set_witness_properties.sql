DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
END;
$BODY$
;



DROP FUNCTION IF EXISTS ASSERT_THIS_TEST;
CREATE FUNCTION ASSERT_THIS_TEST(pname TEXT, pvalue TEXT, expected hive.extract_set_witness_properties_return)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  actual hive.extract_set_witness_properties_return[];
BEGIN
    SELECT ARRAY_AGG(t) INTO actual
    FROM hive.extract_set_witness_properties(
                    json_build_array(
                        json_build_array(
                            pname,
                            pvalue
                        )
            )::TEXT 
    )t;

    ASSERT array_length(actual, 1) = 1, 'Improper amount of data returned by extract_set_witness_properties';
    ASSERT actual[1].prop_name = expected.prop_name, 'Wrong property name returned by extract_set_witness_properties';
    ASSERT actual[1].prop_value::TEXT = expected.prop_value::TEXT, 'Wrong property value returned by extract_set_witness_properties';

END;
$BODY$
;


DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- First two parameters are inputs(pname and pvalue) and the third is the expected result
    -- for hive.extract_set_witness_properties function
    PERFORM ASSERT_THIS_TEST('account_creation_fee', 'b80b00000000000003535445454d0000',('account_creation_fee','{"amount":"3000","precision":3,"nai":"@@000000021"}'));
    PERFORM ASSERT_THIS_TEST('account_subsidy_budget', '1d030000', ('account_subsidy_budget', '797') );
    PERFORM ASSERT_THIS_TEST('account_subsidy_decay', 'b94c0500', ('account_subsidy_decay','347321') :: hive.extract_set_witness_properties_return );
    PERFORM ASSERT_THIS_TEST('hbd_interest_rate', 'dc05', ('hbd_interest_rate','1500') :: hive.extract_set_witness_properties_return );
    PERFORM ASSERT_THIS_TEST('key', '02d912ebc6358fe5b7d86964b9714b5e4d04c2d537c6f6305a2cdfcc22a0b0dc47', ('key','"STM6Y6DSdB5v8GRjAKMuSzGPRhzm5bY9QRqVKqtzUZGj7rNTWcJzZ"') :: hive.extract_set_witness_properties_return );
    PERFORM ASSERT_THIS_TEST('maximum_block_size', '00000100', ('maximum_block_size','65536') :: hive.extract_set_witness_properties_return );
    PERFORM ASSERT_THIS_TEST('new_signing_key', '000000000000000000000000000000000000000000000000000000000000000000', ('new_signing_key','"STM1111111111111111111111111111111114T1Anm"') :: hive.extract_set_witness_properties_return );
    PERFORM ASSERT_THIS_TEST('url', '5b68747470733a2f2f7065616b642e636f6d2f686976652d3131313131312f4073686d6f6f676c656f73756b616d692f68656c702d737570706f72742d636869736465616c6864732d686976652d7769746e6573732d736572766572', ('url','"https://peakd.com/hive-111111/@shmoogleosukami/help-support-chisdealhds-hive-witness-server"'));
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
    -- Nothing to do here
END;
$BODY$
;


