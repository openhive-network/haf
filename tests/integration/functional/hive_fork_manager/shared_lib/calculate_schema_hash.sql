CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
  _pattern TEXT[] := 
ARRAY[
 '{"(blocks,6943f52d-ec57-ed27-b2e3-d8ba4b3288ca,4397b404-c56c-84e1-952e-a73d29745394,4c7b832d-5d52-83fe-fd2b-7e7a69416fae,2b354f61-618a-da7d-3380-3e12c45a3f30)"}',
 '{"(irreversible_data,dd1812c6-cabd-4382-a4bf-c355276b3839,53114e1c-c6e5-867b-6c67-1d55865180fe,77ed7932-7dab-20e3-b506-4a2d3fccfe75,f40cac4c-2fae-a597-11c8-8cc0f329e18f)"}',
 '{"(transactions,a2f346aa-6ef3-1a4b-20fd-8fc5cb11eeb7,d0d1231f-f437-abf1-1f9f-6ae1ed916af4,d1456ff1-2474-ca5b-3b82-be0086c298f0,7766bb78-548b-dc33-4ebe-e5523196b1fb)"}',
 '{"(transactions_multisig,a1cc4195-2d73-eb00-3012-8fbf46dac280,2fae1b96-5a99-7b17-5163-ae45a2b02518,70f65c01-a33c-608b-b0e8-bd29f92615c9,cc576d3f-5919-0a1f-f851-1c008877b33a)"}',
 '{"(operation_types,dd6c8768-2bc2-2b76-3246-292b108f744f,cf35886f-de4e-e064-b170-fd4186ea9148,0dc429a2-22b0-2d05-44d6-cc66d48082b6,08d2ba03-e127-e0ad-aaee-657b3aa27bae)"}',
 '{"(operations,a2ad168d-209f-0aa5-682d-3654fef7da47,5f5183c0-978c-5256-5b2d-de80b7e4f95e,3f9db4b1-53fd-5fb9-947d-36bdc19afa06,b64277f5-829e-7018-d5d3-53f43dfdfae4)"}',
 '{"(applied_hardforks,a5f46bc5-1411-9275-ab7c-4ac4f9067e80,cc12f996-6a6b-d8d1-3c37-567f4affedfb,e9c77910-32e5-8f5a-87f3-cc1d5361c067,b574c705-0de0-5e63-a62e-c98c7917893e)"}',
 '{"(accounts,9c43f538-b5c3-9006-0c76-2a438a32c626,d823f943-fb86-a5be-a277-4029f2ebfd60,d1104ad7-86e7-2870-fcf6-b06c104eba09,13ab4e33-e66a-2b30-cf72-e7ef17888f55)"}',
 '{"(account_operations,ff6755f3-2e11-193a-b68b-3631c6f62b3b,37611791-4f93-7844-5e74-7b6429aad7a2,d4594e73-b464-d65d-e33b-72691c414226,389e0b98-3de7-78e6-ef13-5b619e95a843)"}',
 '{"(fork,a86a9a09-df69-083b-d60d-e08267dd4055,7a370e3d-dce9-c286-ed72-fc52c5ba6dcd,197844f1-1317-5bc9-731b-6a445868da98,8bc60323-f3d8-b277-4470-7d395f37fef8)"}',
 '{"(blocks_reversible,26b08c7f-c597-d8be-82b1-873fa7ef9008,55ac60c5-6fff-bd39-3688-75db00707ee0,ea55e361-2849-0d21-bbd5-66cc76667eec,38cd3744-a4c4-24a5-545a-3b8fb11330ba)"}',
 '{"(transactions_reversible,bd204916-e13d-7977-7270-efcba296291c,80f88569-de6c-46a0-a116-e1dbf87f2177,1158aa24-91c1-dbc9-3f5b-98b1d83717dc,0b19bfdb-f0e2-8936-aa5c-56a41e213bf3)"}',
 '{"(transactions_multisig_reversible,7c089df2-c756-8ea2-41dd-004d2452986c,f59fe248-f829-91a0-fcf8-212ba1c34136,784b72cf-98ee-0e78-8dfd-b8d4746fa297,5e64750e-75a8-686e-1153-706d9850b68a)"}',
 '{"(operations_reversible,3571b026-de38-856b-c2e7-d7a4f699571f,d79d7f42-84dc-ae99-bc53-d8a36ee625cd,47f2295e-a9a6-e487-9609-b4f83da76050,c45f52dc-9604-6afa-9308-80bc050e34c4)"}',
 '{"(accounts_reversible,4bf88047-1295-43ae-59f6-86124fa7b53f,d092cacd-a1ca-369a-0307-82b31779bb5b,c80ea5a5-3499-c1de-8ae0-a0ba05c4f6e3,d5fdf00a-dcf2-2447-bf72-2fb090af3ed0)"}',
 '{"(account_operations_reversible,98e4ec7f-eb29-f2f2-136a-763f89c02a14,fdcb8d9c-ca91-e57e-fe73-88aa2548f8c0,41c0c887-e689-bae9-c7f9-0b3b445708af,4ab1b388-8d83-cd22-76c8-5f9d9596e11f)"}',
 '{"(applied_hardforks_reversible,f5129d5e-5b98-7f93-b786-d55899b5b8b5,d6cca068-2076-4e87-5c24-85618ff564ac,fee57151-3162-0c46-424a-da912e742160,3eeef00d-0e16-421e-659e-7ee2b12aa7eb)"}',
 '{"(contexts,17bf3cac-bcae-5014-2313-dbbc835de1e6,c09d0e4e-819a-4fc7-fec7-7d3f77ff4090,4a82cf7a-fd28-61ec-f852-e591c0690ad0,8672562f-b341-b429-c70d-0d9a00dd18d7)"}'
];
 _schema_hash TEXT[];
 _pass BOOLEAN;
BEGIN

_schema_hash[1] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='blocks'
;

_schema_hash[2] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='irreversible_data'
;

_schema_hash[3] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions'
;

_schema_hash[4] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions_multisig'
;

_schema_hash[5] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='operation_types'
;

_schema_hash[6] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='operations'
;

_schema_hash[7] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='applied_hardforks'
;

_schema_hash[8] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='accounts'
;

_schema_hash[9] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='account_operations'
;

_schema_hash[10] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='fork'
;

_schema_hash[11] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='blocks_reversible'
;

_schema_hash[12] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions_reversible'
;

_schema_hash[13] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='transactions_multisig_reversible'
;

_schema_hash[14] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='operations_reversible'
;

_schema_hash[15] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='accounts_reversible'
;

_schema_hash[16] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='account_operations_reversible'
;

_schema_hash[17] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='applied_hardforks_reversible'
;

_schema_hash[18] := ARRAY_AGG(ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::TEXT)
FROM hive.calculate_schema_hash('hive') f WHERE table_name='contexts'
;

_pass = true;
for i in 1..18 loop
  if _pattern[i] != _schema_hash[i] THEN
    RAISE NOTICE 'new schema hash: %', _schema_hash[i];
    _pass = false;
  end if;
end loop;
ASSERT _pass, 'Schema has changed, update hashes';

END;
$BODY$
;


