DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
  ASSERT (select hive.operation_from_jsontext('{"type":"system_warning_operation","value":{"message":""}}') = '\x5200');

  ASSERT (select hive.operation_from_jsontext('{"type":"system_warning_operation","value":{"message":"abc"}}') = '\x5203616263');

  ASSERT (select hive.operation_from_jsontext('{"type":"limit_order_cancel_operation","value":{"owner":"complexring","orderid":4294967295}}') = '\x060b636f6d706c657872696e67ffffffff');

  ASSERT (select hive.operation_from_jsontext('{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}') = '\x52146e6f20696d706163746564206163636f756e7473');

  ASSERT (select hive.operation_from_jsontext('{
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
}') =
'\x0e08736d696e6572313000015d56d6e721ede5aad1babb0fe818203cbeeb2a000000000000000306b7270831d7e89a5d2b23ba614e6af9f587d2916cbd8f5fd736faa08acdda1ac55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b1fbce97f375ac58c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81a00000000049711861bce6185671b672696eca64398586a66319eacd875155b77fca08601000000000003535445454d000000000200e803');

BEGIN
  PERFORM hive.operation_from_jsontext('{}');
  RAISE EXCEPTION 'Operation cannot be created from an empty object';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM hive.operation_from_jsontext('{"type":"system_warning_operation","value":{"message":[]}}');
  RAISE EXCEPTION 'Operation should not be created from json with incorrect message field';
EXCEPTION WHEN invalid_text_representation THEN
END;

END;
$BODY$
;
