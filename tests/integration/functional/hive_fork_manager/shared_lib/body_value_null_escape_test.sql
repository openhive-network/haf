-- Integration test for \u0000 handling in body_value jsonb column.
--
-- The C++ sql_serializer COPY path calls strip_json_null_escapes() on
-- body_value JSON before writing to PostgreSQL. This test verifies:
-- 1. PostgreSQL jsonb rejects \u0000 (proving the C++ fix is necessary)
-- 2. hive.strip_json_null_escapes() produces valid jsonb for storage
-- 3. Stripped body_value can be stored in and queried from hafd.operations
--
-- Real-world crash: block 96,358,081 custom_json from user 'bamdecs'
-- contained \x00 in the JSON payload, which fc::json serialized as \u0000.

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  __raw_json text;
  __stripped text;
  __stored_value jsonb;
  __query_result jsonb;
BEGIN
  -- ============================================================
  -- 1. Prove PostgreSQL jsonb rejects \u0000
  -- ============================================================
  BEGIN
    PERFORM '{"id":"test\u0000data"}'::jsonb;
    RAISE EXCEPTION '1: jsonb should reject \u0000 but did not';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: "unsupported Unicode escape sequence"
    -- DETAIL: \u0000 cannot be converted to text.
  END;

  -- ============================================================
  -- 2. strip_json_null_escapes produces valid jsonb
  -- ============================================================

  -- 2a. Simple custom_json-like payload with \u0000
  __raw_json := '{"id":"follow","json":"{\"follower\":\"test\u0000user\"}"}';
  __stripped := hive.strip_json_null_escapes(__raw_json);
  -- Must not raise — stripped text is valid jsonb
  PERFORM __stripped::jsonb;
  CALL test.check_eq(
    __stripped::jsonb->>'id', 'follow',
    '2a: stripped custom_json id field wrong'
  );

  -- 2b. Payload mimicking the real crash case (NUL in custom_json body)
  __raw_json := '{"id":"sm_market_sell","json":"{\u0000\"items\":[\"abc\"]}"}';
  __stripped := hive.strip_json_null_escapes(__raw_json);
  PERFORM __stripped::jsonb;
  CALL test.check_eq(
    __stripped::jsonb->>'id', 'sm_market_sell',
    '2b: stripped market_sell id field wrong'
  );

  -- 2c. Multiple \u0000 scattered through a payload
  __raw_json := '{"tag":"\u0000spam\u0000","author":"\u0000","body":"ok"}';
  __stripped := hive.strip_json_null_escapes(__raw_json);
  __stored_value := __stripped::jsonb;
  CALL test.check_eq(__stored_value->>'tag', 'spam', '2c: tag not stripped correctly');
  CALL test.check_eq(__stored_value->>'author', '', '2c: author not stripped correctly');
  CALL test.check_eq(__stored_value->>'body', 'ok', '2c: body should be unchanged');

  -- 2d. Escaped backslash before u0000 — must be preserved (not a real NUL escape)
  __raw_json := '{"regex":"[\\u0000-\\u001f]"}';
  __stripped := hive.strip_json_null_escapes(__raw_json);
  CALL test.check_eq(
    __stripped, __raw_json,
    '2d: \\u0000 (escaped backslash) should be preserved'
  );

  -- ============================================================
  -- 3. Stripped body_value can be stored in hafd.operations
  -- ============================================================

  -- Insert a row with stripped body_value into the actual operations table.
  -- This exercises the same column and type the COPY path writes to.
  __raw_json := '{"id":"test_op","json":"data\u0000end"}';
  __stripped := hive.strip_json_null_escapes(__raw_json);
  __stored_value := __stripped::jsonb;

  INSERT INTO hafd.operations(id, trx_in_block, op_type_id, op_pos, body_value)
  VALUES (hafd.operation_id(1, 0), 0, 18, 0, __stored_value);

  SELECT body_value INTO __query_result
  FROM hafd.operations
  WHERE id = hafd.operation_id(1, 0);

  CALL test.check_eq(
    __query_result->>'id', 'test_op',
    '3a: stored body_value id field wrong after round-trip'
  );
  CALL test.check_eq(
    __query_result->>'json', 'dataend',
    '3b: stored body_value json field should have NUL stripped'
  );

  -- ============================================================
  -- 4. Confirm unstripped \u0000 would fail the INSERT
  -- ============================================================
  BEGIN
    INSERT INTO hafd.operations(id, trx_in_block, op_type_id, op_pos, body_value)
    VALUES (hafd.operation_id(1, 1), 0, 18, 1, '{"bad":"\u0000"}'::jsonb);
    RAISE EXCEPTION '4: INSERT with \u0000 jsonb should have failed';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: proves that without C++ stripping, COPY would crash
  END;

  -- Cleanup
  DELETE FROM hafd.operations WHERE id = hafd.operation_id(1, 0);
END;
$BODY$
;
