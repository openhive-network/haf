DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
  ASSERT (SELECT '{"type":"system_warning_operation","value":{"message":""}}'::jsonb::hive.operation = '\x5200');

  ASSERT (SELECT '{"type":"system_warning_operation","value":{"message":"abc"}}'::jsonb::hive.operation = '\x5203616263');

  ASSERT (SELECT '{"type":"limit_order_cancel_operation","value":{"owner":"complexring","orderid":4294967295}}'::jsonb::hive.operation = '\x060b636f6d706c657872696e67ffffffff');

  ASSERT (SELECT '{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}'::jsonb::hive.operation = '\x52146e6f20696d706163746564206163636f756e7473');

BEGIN
  PERFORM '{}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation cannot be created from an empty object';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"system_warning_operation","value":{"message":[]}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created from json with incorrect message field';
EXCEPTION WHEN invalid_text_representation THEN
END;

END;
$BODY$
;
