CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
  -- Cast results to jsonb to ignore ordering issues
  CALL hive.check_eq( hive.operation_to_jsontext('\x5200')::jsonb,
    '{"type":"system_warning_operation","value":{"message":""}}'::jsonb);

  CALL hive.check_eq( hive.operation_to_jsontext('\x5203616263')::jsonb,
    '{"type":"system_warning_operation","value":{"message":"abc"}}'::jsonb);

  CALL hive.check_eq( hive.operation_to_jsontext('\x060b636f6d706c657872696e67ffffffff')::jsonb,
    '{"type":"limit_order_cancel_operation","value":{"owner":"complexring","orderid":4294967295}}'::jsonb);

  CALL hive.check_eq( hive.operation_to_jsontext('\x52146e6f20696d706163746564206163636f756e7473')::jsonb,
    '{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}'::jsonb);

  CALL hive.check_eq(hive.operation_to_jsontext('\x0e08736d696e6572313000015d56d6e721ede5aad1babb0fe818203cbeeb2a000000000000000306b7270831d7e89a5d2b23ba614e6af9f587d2916cbd8f5fd736faa08acdda1ac55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b1fbce97f375ac58c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81a00000000049711861bce6185671b672696eca64398586a66319eacd875155b77fca08601000000000003535445454d000000000200e803')::jsonb,
'{
    "type": "pow_operation",
    "value": {
        "work": {
            "work": "000000049711861bce6185671b672696eca64398586a66319eacd875155b77fc",
            "input": "c55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b",
            "worker": "STM6tC4qRjUPKmkqkug5DvSgkeND5DHhnfr3XTgpp4b4nejMEwn9k",
            "signature": "1fbce97f375ac58c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81a00"
        },
        "nonce": 42,
        "props": {
            "hbd_interest_rate": 1000,
            "maximum_block_size": 131072,
            "account_creation_fee": {
                "nai": "@@000000021",
                "amount": "100000",
                "precision": 3
            }
        },
        "block_id": "00015d56d6e721ede5aad1babb0fe818203cbeeb",
        "worker_account": "sminer10"
    }
}'::jsonb);

BEGIN
  PERFORM hive.operation_to_jsontext('\x52');
  RAISE EXCEPTION 'Not enough bytes to convert to operation';
EXCEPTION WHEN invalid_binary_representation THEN
END;

END;
$BODY$
;
