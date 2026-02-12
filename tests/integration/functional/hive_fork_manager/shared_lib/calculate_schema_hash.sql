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
    '(block_conflicts,c0baccac-c8e1-1f65-85d1-57a56f687de0,48df8c18-7794-573e-601d-580e1e12f738,35e2417f-017e-56a7-7e7d-11ec98cd9dc9,d9ced447-ace5-bef7-b48d-7a3e74843543)',
    '(blocks,f25219a3-4e13-04aa-656c-36e5f5a4f5f2,df7ef152-1122-b7df-4ba9-3e897b525177,502c4352-efbb-5ed4-8aec-5e3b0d595c97,8bc54892-1c23-1bf6-b665-8e6b979d342d)',
    '(hive_state,c7eba493-aaad-04d3-b545-49920b1438bd,2a00f809-f4f9-e96b-d4f1-e21c3357f978,1ec06445-c874-940f-99b4-7ba919d368b5,db0a6fb3-b072-2629-7a5d-0fa6487b43f5)',
    '(transactions,ad3efcab-27ed-bb9e-c19c-37642e2bb653,e95c750f-ecf6-2118-296b-adfd870a8b68,aa080da1-a419-ee7e-f9ba-24b2f7304c39,db5eb531-5870-96a0-623e-07f6ee2b386d)',
    '(transactions_multisig,928f3485-398c-deec-d3bc-3d18d4f0b424,e35319f3-c226-337c-47b5-3f1509cc1d9f,e5266700-fa13-5b11-ad67-84a67c73b89e,7156512e-e9bd-d975-1379-68f0ac1b7fe7)',
    '(operation_types,dd6c8768-2bc2-2b76-3246-292b108f744f,cf35886f-de4e-e064-b170-fd4186ea9148,0dc429a2-22b0-2d05-44d6-cc66d48082b6,08d2ba03-e127-e0ad-aaee-657b3aa27bae)',
    '(operations,6ff5a57a-b9f2-dae7-7565-a5bafeadff08,555761cf-ad2c-edd7-eff8-1e18473592de,3f9db4b1-53fd-5fb9-947d-36bdc19afa06,5eed2567-42d4-de86-31e8-ed2a3e2a5067)',
    '(applied_hardforks,62db9435-9194-e1a1-4836-d1e6fada7743,807eb203-0aef-3c9d-d4db-25a0201b229c,f0495fa5-8a19-51a1-9ac9-d47bc89deeb0,654806b4-c223-2b06-c4c5-44b320bf7068)',
    '(accounts,4592b799-551e-f242-cf3c-b913011ecb58,18dd421d-3f9d-0b0f-b5f6-87a84d08a72b,95d7e032-99aa-eb63-87a0-1519f1fc374c,7100edc3-37dc-5285-a155-82256ffea50c)',
    '(account_operations,5cad119d-bcb5-dd51-4557-47d2d482f8a5,91571750-5efe-4b10-e6ea-52531f659231,57b01225-7781-ef33-d57c-10bc2cb854d3,48960a86-efb0-b9ba-7108-b1daa4a0dc9f)',
    '(fork,a86a9a09-df69-083b-d60d-e08267dd4055,7a370e3d-dce9-c286-ed72-fc52c5ba6dcd,197844f1-1317-5bc9-731b-6a445868da98,8bc60323-f3d8-b277-4470-7d395f37fef8)',
    '(contexts_attachment,c99e00c4-bc99-eb5d-1071-310575d2655a,0007a55e-0b74-b8b1-fb0d-a2e2b82a05bd,3e2b74cd-8a9a-2768-c01b-c8a307e8267d,90df8e77-2984-5c96-2a9f-908b8e7604dc)',
    '(contexts,a1841d23-3612-d633-60d9-5ab41612d85c,5dc37b1c-1cb2-f279-92d4-cf025c786f4e,4a82cf7a-fd28-61ec-f852-e591c0690ad0,8672562f-b341-b429-c70d-0d9a00dd18d7)',
    '(contexts_log,80122d29-15e5-b9a7-30e2-1cf4987bd9c9,aa673368-dc31-cf26-d7ec-fa46acd87a32,10c38e8d-5c8f-f588-0f62-9dab0e663ba6,e3d046e4-144c-4cda-176c-0f7f1a690d08)',
    '(vacuum_requests,744196e0-2be8-3067-2a04-e39873eae50a,695e4322-2320-828a-8bb8-0ee4844f70c6,402279c7-c8d7-607f-60e3-76d8d3457595,33efbf60-093b-541d-66b4-935c77d4d0e3)',
    '(table_schema,1b414fdc-af7d-4859-1a10-9ab25fe967fd,858a9152-2f70-a7d2-fe74-26b3107e8082,ba2b45bd-c11e-2a4a-6e86-aab2ac693cbb,ba2b45bd-c11e-2a4a-6e86-aab2ac693cbb)',
    '(write_ahead_log_state,3c18769a-7950-ff27-266a-9be458ad73d0,965e0911-8d91-bef3-8a23-c92726e98508,5b8e1f09-4d13-91f1-53fa-dcdb4986e28d,3ff4519c-6dc0-2a9f-1e19-249f92ace076)',
    '(state_providers_registered,b41e740b-372c-cbf5-c89e-121fc30ae222,e5256de7-28e9-0079-dd6d-c410fb648f41,47f62787-773b-c098-9df3-4a9bae4b65c0,3b033100-aacc-10b4-16f9-1dcf27656',
    '(triggers,68b875fc-1585-3fbd-9356-621f6fcb6f2d,407c0130-fb27-1258-6e00-b5356a4e37e9,d07c39bb-6037-3ad3-981e-d8307199a726,39645c85-ddd1-fddd-3679-f8e8d91c55d3)',
    '(indexes_constraints,6a2dcd7d-8ed7-ffa5-377d-3346b6348b0c,a5b015d4-3334-da4f-e336-6f77738e9fba,50e7a3da-5999-2fb3-865b-61d701d67bc1,7ff09584-f530-c98d-1e12-bffd6f4c907b)',
    '(hived_connections,20fd6a8a-592b-e76d-eb93-15b4c57de3c2,5439bb50-0630-305a-034f-87c9326a6ded,f07addc5-dce8-5bb5-1b79-9ec821cc279b,09c1aed4-677c-d4eb-a405-35e973f89188)',
    '(deps_saved_ddl,ea91c6c0-eb6a-b473-eb1c-e426eadb1d09,549ba4bd-64d6-c554-11f4-d27e4b37b6e6,d3176a21-5841-14c3-0d52-6566cf12299e,cc8a1233-564b-27fd-3ffd-ce376cd366f7)',
    '(registered_tables,01d11432-b7d9-fb8e-a345-2e412e782cfd,ff824909-7631-1102-16f9-5b6ba2f88b74,07ad4206-ab16-75cc-4aaa-18ed4006d4f6,fe6f193c-4d9c-266a-3f43-0a67d8a6dcfb)',
    '(events_queue,47c432ad-9eab-ba67-7956-1c14fa210dec,0a710f7b-0af2-9ec6-b1eb-37e181e01473,a5e6d444-fbcd-9518-618b-cc3479932005,48a3b028-2a9e-c01e-0615-0737d43b7b81)',
    '(state_providers_registered,b41e740b-372c-cbf5-c89e-121fc30ae222,e5256de7-28e9-0079-dd6d-c410fb648f41,47f62787-773b-c098-9df3-4a9bae4b65c0,3b033100-aacc-10b4-16f9-1dcf276565ff)',
    '(custom_json_types,6bd7060c-a1f3-21fd-013d-cdba0fd46c8e,f5fe705b-9760-b531-d8a0-3d795733a6df,c66fbf43-cb33-301a-20b3-685c2f3e4c4c,5ec0224a-2b65-f83a-6d9d-61363595386f)'
  ])
LOOP
    RAISE NOTICE 'new schema hash: %', _row;
END LOOP;
ASSERT NOT FOUND, 'Schema has changed, update hashes';
END;
$BODY$
;
