CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
  _row TEXT;
BEGIN
FOR _row in
  SELECT (ROW(f.table_name, f.table_schema_hash, f.columns_hash, f.constraints_hash, f.indexes_hash)::text) FROM hive_update.calculate_schema_hash() AS f
  EXCEPT SELECT unnest(ARRAY[
    '(blocks,6943f52d-ec57-ed27-b2e3-d8ba4b3288ca,4397b404-c56c-84e1-952e-a73d29745394,4c7b832d-5d52-83fe-fd2b-7e7a69416fae,2b354f61-618a-da7d-3380-3e12c45a3f30)',
    '(irreversible_data,dd1812c6-cabd-4382-a4bf-c355276b3839,53114e1c-c6e5-867b-6c67-1d55865180fe,77ed7932-7dab-20e3-b506-4a2d3fccfe75,f40cac4c-2fae-a597-11c8-8cc0f329e18f)',
    '(transactions,a2f346aa-6ef3-1a4b-20fd-8fc5cb11eeb7,d0d1231f-f437-abf1-1f9f-6ae1ed916af4,d1456ff1-2474-ca5b-3b82-be0086c298f0,7766bb78-548b-dc33-4ebe-e5523196b1fb)',
    '(transactions_multisig,a1cc4195-2d73-eb00-3012-8fbf46dac280,2fae1b96-5a99-7b17-5163-ae45a2b02518,70f65c01-a33c-608b-b0e8-bd29f92615c9,cc576d3f-5919-0a1f-f851-1c008877b33a)',
    '(operation_types,dd6c8768-2bc2-2b76-3246-292b108f744f,cf35886f-de4e-e064-b170-fd4186ea9148,0dc429a2-22b0-2d05-44d6-cc66d48082b6,08d2ba03-e127-e0ad-aaee-657b3aa27bae)',
    '(operations,a71b992e-0118-d124-9f18-937add5510f7,12f5d64b-0175-777f-7b59-c7095e907eae,3f9db4b1-53fd-5fb9-947d-36bdc19afa06,b64277f5-829e-7018-d5d3-53f43dfdfae4)',
    '(applied_hardforks,a5f46bc5-1411-9275-ab7c-4ac4f9067e80,cc12f996-6a6b-d8d1-3c37-567f4affedfb,e9c77910-32e5-8f5a-87f3-cc1d5361c067,b574c705-0de0-5e63-a62e-c98c7917893e)',
    '(accounts,9c43f538-b5c3-9006-0c76-2a438a32c626,d823f943-fb86-a5be-a277-4029f2ebfd60,d1104ad7-86e7-2870-fcf6-b06c104eba09,13ab4e33-e66a-2b30-cf72-e7ef17888f55)',
    '(account_operations,af9635f6-a53a-4d1b-dd59-72ec62ec8a9a,1b7a541f-b720-b158-7857-962085ce242b,6b08189b-025e-c3bb-23f0-01e7d61e234f,227973e8-699f-2c16-4e52-1773bb726a93)',
    '(fork,a86a9a09-df69-083b-d60d-e08267dd4055,7a370e3d-dce9-c286-ed72-fc52c5ba6dcd,197844f1-1317-5bc9-731b-6a445868da98,8bc60323-f3d8-b277-4470-7d395f37fef8)',
    '(blocks_reversible,26b08c7f-c597-d8be-82b1-873fa7ef9008,55ac60c5-6fff-bd39-3688-75db00707ee0,ea55e361-2849-0d21-bbd5-66cc76667eec,38cd3744-a4c4-24a5-545a-3b8fb11330ba)',
    '(transactions_reversible,bd204916-e13d-7977-7270-efcba296291c,80f88569-de6c-46a0-a116-e1dbf87f2177,1158aa24-91c1-dbc9-3f5b-98b1d83717dc,0b19bfdb-f0e2-8936-aa5c-56a41e213bf3)',
    '(transactions_multisig_reversible,7c089df2-c756-8ea2-41dd-004d2452986c,f59fe248-f829-91a0-fcf8-212ba1c34136,784b72cf-98ee-0e78-8dfd-b8d4746fa297,5e64750e-75a8-686e-1153-706d9850b68a)',
    '(operations_reversible,0b3b84b2-702f-38ab-4ec0-c0184f376d66,47f1e378-6d4d-7e15-b5e5-e57934b173dd,47f2295e-a9a6-e487-9609-b4f83da76050,c45f52dc-9604-6afa-9308-80bc050e34c4)',
    '(accounts_reversible,4bf88047-1295-43ae-59f6-86124fa7b53f,d092cacd-a1ca-369a-0307-82b31779bb5b,c80ea5a5-3499-c1de-8ae0-a0ba05c4f6e3,d5fdf00a-dcf2-2447-bf72-2fb090af3ed0)',
    '(account_operations_reversible,1e6127e3-0ee0-cfea-fc51-0454061315c3,465f67a5-4c10-f8ed-39be-4365e4553fd7,41c0c887-e689-bae9-c7f9-0b3b445708af,1528735c-e90f-8b11-d30a-86dddedb3676)',
    '(applied_hardforks_reversible,f5129d5e-5b98-7f93-b786-d55899b5b8b5,d6cca068-2076-4e87-5c24-85618ff564ac,fee57151-3162-0c46-424a-da912e742160,3eeef00d-0e16-421e-659e-7ee2b12aa7eb)',
    '(contexts_attachment,c99e00c4-bc99-eb5d-1071-310575d2655a,0007a55e-0b74-b8b1-fb0d-a2e2b82a05bd,3e2b74cd-8a9a-2768-c01b-c8a307e8267d,90df8e77-2984-5c96-2a9f-908b8e7604dc)',
    '(contexts,a1841d23-3612-d633-60d9-5ab41612d85c,5dc37b1c-1cb2-f279-92d4-cf025c786f4e,4a82cf7a-fd28-61ec-f852-e591c0690ad0,8672562f-b341-b429-c70d-0d9a00dd18d7)',
    '(contexts_log,80122d29-15e5-b9a7-30e2-1cf4987bd9c9,aa673368-dc31-cf26-d7ec-fa46acd87a32,10c38e8d-5c8f-f588-0f62-9dab0e663ba6,e3d046e4-144c-4cda-176c-0f7f1a690d08)',
    '(vacuum_requests,e0d1500f-e440-5a93-4a7a-0f3f0446f21c,55f334e7-8bef-89eb-4295-2c94cecbf1fe,402279c7-c8d7-607f-60e3-76d8d3457595,65702f1d-5458-38b8-72cd-d813da62d268)',
    '(table_schema,1b414fdc-af7d-4859-1a10-9ab25fe967fd,858a9152-2f70-a7d2-fe74-26b3107e8082,ba2b45bd-c11e-2a4a-6e86-aab2ac693cbb,ba2b45bd-c11e-2a4a-6e86-aab2ac693cbb)',
    '(write_ahead_log_state,3c18769a-7950-ff27-266a-9be458ad73d0,965e0911-8d91-bef3-8a23-c92726e98508,5b8e1f09-4d13-91f1-53fa-dcdb4986e28d,3ff4519c-6dc0-2a9f-1e19-249f92ace076)',
    '(state_providers_registered,b41e740b-372c-cbf5-c89e-121fc30ae222,e5256de7-28e9-0079-dd6d-c410fb648f41,47f62787-773b-c098-9df3-4a9bae4b65c0,3b033100-aacc-10b4-16f9-1dcf27656',
    '(triggers,68b875fc-1585-3fbd-9356-621f6fcb6f2d,407c0130-fb27-1258-6e00-b5356a4e37e9,d07c39bb-6037-3ad3-981e-d8307199a726,39645c85-ddd1-fddd-3679-f8e8d91c55d3)',
    '(indexes_constraints,6a2dcd7d-8ed7-ffa5-377d-3346b6348b0c,a5b015d4-3334-da4f-e336-6f77738e9fba,50e7a3da-5999-2fb3-865b-61d701d67bc1,7ff09584-f530-c98d-1e12-bffd6f4c907b)',
    '(hived_connections,20fd6a8a-592b-e76d-eb93-15b4c57de3c2,5439bb50-0630-305a-034f-87c9326a6ded,f07addc5-dce8-5bb5-1b79-9ec821cc279b,09c1aed4-677c-d4eb-a405-35e973f89188)',
    '(deps_saved_ddl,ea91c6c0-eb6a-b473-eb1c-e426eadb1d09,549ba4bd-64d6-c554-11f4-d27e4b37b6e6,d3176a21-5841-14c3-0d52-6566cf12299e,cc8a1233-564b-27fd-3ffd-ce376cd366f7)',
    '(registered_tables,01d11432-b7d9-fb8e-a345-2e412e782cfd,ff824909-7631-1102-16f9-5b6ba2f88b74,07ad4206-ab16-75cc-4aaa-18ed4006d4f6,fe6f193c-4d9c-266a-3f43-0a67d8a6dcfb)',
    '(events_queue,47c432ad-9eab-ba67-7956-1c14fa210dec,0a710f7b-0af2-9ec6-b1eb-37e181e01473,a5e6d444-fbcd-9518-618b-cc3479932005,48a3b028-2a9e-c01e-0615-0737d43b7b81)',
    '(state_providers_registered,b41e740b-372c-cbf5-c89e-121fc30ae222,e5256de7-28e9-0079-dd6d-c410fb648f41,47f62787-773b-c098-9df3-4a9bae4b65c0,3b033100-aacc-10b4-16f9-1dcf276565ff)'
  ])
LOOP
    RAISE NOTICE 'new schema hash: %', _row;
END LOOP;
ASSERT NOT FOUND, 'Schema has changed, update hashes';
END;
$BODY$
;
