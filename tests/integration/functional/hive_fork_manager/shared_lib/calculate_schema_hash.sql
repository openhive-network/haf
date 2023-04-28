DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
  _pattern0 TEXT[] = '{"(blocks,6943f52d-ec57-ed27-b2e3-d8ba4b3288ca,4397b404-c56c-84e1-952e-a73d29745394,4c7b832d-5d52-83fe-fd2b-7e7a69416fae,2b354f61-618a-da7d-3380-3e12c45a3f30)"}';
  _test0 TEXT[];

  _pattern1 TEXT[] = '{"(irreversible_data,dd1812c6-cabd-4382-a4bf-c355276b3839,53114e1c-c6e5-867b-6c67-1d55865180fe,77ed7932-7dab-20e3-b506-4a2d3fccfe75,f40cac4c-2fae-a597-11c8-8cc0f329e18f)"}';
  _test1 TEXT[];

  _pattern2 TEXT[] = '{"(transactions,a2f346aa-6ef3-1a4b-20fd-8fc5cb11eeb7,d0d1231f-f437-abf1-1f9f-6ae1ed916af4,d1456ff1-2474-ca5b-3b82-be0086c298f0,7766bb78-548b-dc33-4ebe-e5523196b1fb)"}';
  _test2 TEXT[];

  _pattern3 TEXT[] = '{"(transactions_multisig,a1cc4195-2d73-eb00-3012-8fbf46dac280,2fae1b96-5a99-7b17-5163-ae45a2b02518,70f65c01-a33c-608b-b0e8-bd29f92615c9,cc576d3f-5919-0a1f-f851-1c008877b33a)"}';
  _test3 TEXT[];

  _pattern4 TEXT[] = '{"(operation_types,dd6c8768-2bc2-2b76-3246-292b108f744f,cf35886f-de4e-e064-b170-fd4186ea9148,0dc429a2-22b0-2d05-44d6-cc66d48082b6,08d2ba03-e127-e0ad-aaee-657b3aa27bae)"}';
  _test4 TEXT[];

  _pattern5 TEXT[] = '{"(operations,c9225f58-2a8a-a8ab-a0ce-0393f0f3256f,b1580b50-98e8-32e0-f3fd-394537a7fd74,dc112f75-3d2c-62c9-88cd-cb4247c91fc0,351e13b9-b6b9-96e2-a5cc-4cca83d5d913)"}';
  _test5 TEXT[];

  _pattern6 TEXT[] = '{"(applied_hardforks,a5f46bc5-1411-9275-ab7c-4ac4f9067e80,cc12f996-6a6b-d8d1-3c37-567f4affedfb,e9c77910-32e5-8f5a-87f3-cc1d5361c067,b574c705-0de0-5e63-a62e-c98c7917893e)"}';
  _test6 TEXT[];

  _pattern7 TEXT[] = '{"(accounts,9c43f538-b5c3-9006-0c76-2a438a32c626,d823f943-fb86-a5be-a277-4029f2ebfd60,d1104ad7-86e7-2870-fcf6-b06c104eba09,13ab4e33-e66a-2b30-cf72-e7ef17888f55)"}';
  _test7 TEXT[];

  _pattern8 TEXT[] = '{"(account_operations,11e4a069-a324-7048-d1c7-a5a9dcbf5119,37611791-4f93-7844-5e74-7b6429aad7a2,5c8c64a2-b577-bea3-17d8-f678775e7454,35365591-23e8-59e5-6153-98a5b2e0bde7)"}';
  _test8 TEXT[];

  _pattern9 TEXT[] = '{"(fork,a86a9a09-df69-083b-d60d-e08267dd4055,7a370e3d-dce9-c286-ed72-fc52c5ba6dcd,197844f1-1317-5bc9-731b-6a445868da98,8bc60323-f3d8-b277-4470-7d395f37fef8)"}';
  _test9 TEXT[];

  _pattern10 TEXT[] = '{"(blocks_reversible,26b08c7f-c597-d8be-82b1-873fa7ef9008,55ac60c5-6fff-bd39-3688-75db00707ee0,ea55e361-2849-0d21-bbd5-66cc76667eec,38cd3744-a4c4-24a5-545a-3b8fb11330ba)"}';
  _test10 TEXT[];

  _pattern11 TEXT[] = '{"(transactions_reversible,bd204916-e13d-7977-7270-efcba296291c,80f88569-de6c-46a0-a116-e1dbf87f2177,1158aa24-91c1-dbc9-3f5b-98b1d83717dc,0b19bfdb-f0e2-8936-aa5c-56a41e213bf3)"}';
  _test11 TEXT[];

  _pattern12 TEXT[] = '{"(transactions_multisig_reversible,7c089df2-c756-8ea2-41dd-004d2452986c,f59fe248-f829-91a0-fcf8-212ba1c34136,784b72cf-98ee-0e78-8dfd-b8d4746fa297,5e64750e-75a8-686e-1153-706d9850b68a)"}';
  _test12 TEXT[];

  _pattern13 TEXT[] = '{"(operations_reversible,28d0770d-7b1f-ef6b-71cd-ccf2d9edd638,18cb3ebd-cc0f-1372-4785-6a2738c5cfac,eab2b539-709f-09cc-33ae-5df59a6f64a2,6c9dc56c-5b3d-13f8-8a68-a961d9290fa3)"}';
  _test13 TEXT[];

  _pattern14 TEXT[] = '{"(accounts_reversible,4bf88047-1295-43ae-59f6-86124fa7b53f,d092cacd-a1ca-369a-0307-82b31779bb5b,c80ea5a5-3499-c1de-8ae0-a0ba05c4f6e3,d5fdf00a-dcf2-2447-bf72-2fb090af3ed0)"}';
  _test14 TEXT[];

  _pattern15 TEXT[] = '{"(account_operations_reversible,98e4ec7f-eb29-f2f2-136a-763f89c02a14,fdcb8d9c-ca91-e57e-fe73-88aa2548f8c0,41c0c887-e689-bae9-c7f9-0b3b445708af,4ab1b388-8d83-cd22-76c8-5f9d9596e11f)"}';
  _test15 TEXT[];

  _pattern16 TEXT[] = '{"(applied_hardforks_reversible,f5129d5e-5b98-7f93-b786-d55899b5b8b5,d6cca068-2076-4e87-5c24-85618ff564ac,fee57151-3162-0c46-424a-da912e742160,3eeef00d-0e16-421e-659e-7ee2b12aa7eb)"}';
  _test16 TEXT[];

  _pattern17 TEXT[] = '{"(contexts,e463f3df-87a5-a38d-3bb9-bad3bc7d3782,6328f066-eb45-a60e-0395-2eff483185f8,4a82cf7a-fd28-61ec-f852-e591c0690ad0,8672562f-b341-b429-c70d-0d9a00dd18d7)"}';
  _test17 TEXT[];

BEGIN

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test0
FROM hive.calculate_schema_hash('hive') f WHERE table_name='blocks'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test1
FROM hive.calculate_schema_hash('hive') f WHERE table_name='irreversible_data'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test2
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test3
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions_multisig'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test4
FROM hive.calculate_schema_hash('hive') f WHERE table_name='operation_types'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test5
FROM hive.calculate_schema_hash('hive') f WHERE table_name='operations'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test6
FROM hive.calculate_schema_hash('hive') f WHERE table_name='applied_hardforks'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test7
FROM hive.calculate_schema_hash('hive') f WHERE table_name='accounts'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test8
FROM hive.calculate_schema_hash('hive') f WHERE table_name='account_operations'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test9
FROM hive.calculate_schema_hash('hive') f WHERE table_name='fork'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test10
FROM hive.calculate_schema_hash('hive') f WHERE table_name='blocks_reversible'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test11
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions_reversible'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test12
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions_multisig_reversible'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test13
FROM hive.calculate_schema_hash('hive') f WHERE table_name='operations_reversible'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test14
FROM hive.calculate_schema_hash('hive') f WHERE table_name='accounts_reversible'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test15
FROM hive.calculate_schema_hash('hive') f WHERE table_name='account_operations_reversible'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test16
FROM hive.calculate_schema_hash('hive') f WHERE table_name='applied_hardforks_reversible'
;

SELECT ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
INTO _test17
FROM hive.calculate_schema_hash('hive') f WHERE table_name='contexts'
;

ASSERT _pattern0 = _test0, 'Broken result of calculate_schema_hash in "blocks" row';
ASSERT _pattern1 = _test1, 'Broken result of calculate_schema_hash in "irreversible_data" row';
ASSERT _pattern2 = _test2, 'Broken result of calculate_schema_hash in "transactions" row';
ASSERT _pattern3 = _test3, 'Broken result of calculate_schema_hash in "transactions_multisig" row';
ASSERT _pattern4 = _test4, 'Broken result of calculate_schema_hash in "operation_types" row';
ASSERT _pattern5 = _test5, 'Broken result of calculate_schema_hash in "operations" row';
ASSERT _pattern6 = _test6, 'Broken result of calculate_schema_hash in "applied_hardforks" row';
ASSERT _pattern7 = _test7, 'Broken result of calculate_schema_hash in "accounts" row';
ASSERT _pattern8 = _test8, 'Broken result of calculate_schema_hash in "account_operations" row';
ASSERT _pattern9 = _test9, 'Broken result of calculate_schema_hash in "fork" row';
ASSERT _pattern10 = _test10, 'Broken result of calculate_schema_hash in "blocks_reversible" row';
ASSERT _pattern11 = _test11, 'Broken result of calculate_schema_hash in "transactions_reversible" row';
ASSERT _pattern12 = _test12, 'Broken result of calculate_schema_hash in "transactions_multisig_reversible" row';
ASSERT _pattern13 = _test13, 'Broken result of calculate_schema_hash in "operations_reversible" row';
ASSERT _pattern14 = _test14, 'Broken result of calculate_schema_hash in "accounts_reversible" row';
ASSERT _pattern15 = _test15, 'Broken result of calculate_schema_hash in "account_operations_reversible" row';
ASSERT _pattern16 = _test16, 'Broken result of calculate_schema_hash in "applied_hardforks_reversible" row';
ASSERT _pattern17 = _test17, 'Broken result of calculate_schema_hash in "contexts" row';


END;
$BODY$
;


