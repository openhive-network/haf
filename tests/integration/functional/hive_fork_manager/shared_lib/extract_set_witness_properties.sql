DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- This table contains inputs(pname and pvalue) and patterns (pattern column)
    -- for hive.extract_set_witness_properties function, which is tested in test_when
    CREATE TABLE samples_for_extract_set_witness_properties( pname TEXT, pvalue TEXT, pattern hive.extract_set_witness_properties_return );
    INSERT INTO samples_for_extract_set_witness_properties(pname, pvalue, pattern) VALUES
        ('account_creation_fee', 'b80b00000000000003535445454d0000', ('account_creation_fee','{"amount":"3000","precision":3,"nai":"@@000000021"}') :: hive.extract_set_witness_properties_return ),
        ('account_subsidy_budget', '1d030000', ('account_subsidy_budget', '797') :: hive.extract_set_witness_properties_return ),
        ('account_subsidy_decay', 'b94c0500', ('account_subsidy_decay','347321') :: hive.extract_set_witness_properties_return ),
        ('hbd_interest_rate', 'dc05', ('hbd_interest_rate','1500') :: hive.extract_set_witness_properties_return ),
        ('key', '02d912ebc6358fe5b7d86964b9714b5e4d04c2d537c6f6305a2cdfcc22a0b0dc47', ('key','"STM6Y6DSdB5v8GRjAKMuSzGPRhzm5bY9QRqVKqtzUZGj7rNTWcJzZ"') :: hive.extract_set_witness_properties_return ),
        ('maximum_block_size', '00000100', ('maximum_block_size','65536') :: hive.extract_set_witness_properties_return ),
        ('new_signing_key', '000000000000000000000000000000000000000000000000000000000000000000', ('new_signing_key','"STM1111111111111111111111111111111114T1Anm"') :: hive.extract_set_witness_properties_return ),
        ('url', '5b68747470733a2f2f7065616b642e636f6d2f686976652d3131313131312f4073686d6f6f676c656f73756b616d692f68656c702d737570706f72742d636869736465616c6864732d686976652d7769746e6573732d736572766572', ('url','"https://peakd.com/hive-111111/@shmoogleosukami/help-support-chisdealhds-hive-witness-server"') :: hive.extract_set_witness_properties_return )
    ;
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN

    ASSERT 0 = (SELECT COUNT(*) FROM (
        SELECT (
            (
                hive.extract_set_witness_properties(
                    json_build_array(
                        json_build_array(
                            pname,
                            pvalue
                        )
                    ) ::TEXT
                ) :: TEXT
            ) = (pattern ::TEXT)
        ) as cmp_result
        FROM samples_for_extract_set_witness_properties
    ) x WHERE x.cmp_result != TRUE);

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
    -- Nothing to do here
END;
$BODY$
;


