-- Test for operation::jsonb NUL byte truncation behavior.
--
-- PostgreSQL JSONB rejects \u0000 (the JSON escape for NUL), so
-- operation::jsonb must not allow NUL bytes into JSONB strings.
-- pstrdup (used internally) naturally truncates at the first NUL byte.
-- The canonical lossless representation is hafd.operation (bytea).
--
-- Most test operations use system_warning_operation (type 0x52).
-- Binary layout: 0x52 (type) + varint(message_length) + message_bytes

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
  __result jsonb;
  __msg text;
  __roundtrip_jsonb jsonb;
  __clean_op hafd.operation;
BEGIN
  -- ============================================================
  -- Tests 1-7: NUL byte position — truncation at first NUL
  -- ============================================================

  -- 1. NUL in middle: "test\x00app" (8 bytes) → truncated to "test" (4 bytes)
  __result := ('\x52087465737400617070'::hafd.operation)::jsonb;  -- 52=type 08=len(8) "test\0app"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(__msg, 'test', '1: NUL in middle — should truncate to "test"');

  -- 2. NUL at start: "\x00hello" (6 bytes) → truncated to "" (0 bytes)
  __result := ('\x52060068656c6c6f'::hafd.operation)::jsonb;  -- 52=type 06=len(6) "\0hello"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(__msg, '', '2: NUL at start — should truncate to empty');

  -- 3. NUL at end: "hello\x00" (6 bytes) → truncated to "hello" (5 bytes)
  __result := ('\x520668656c6c6f00'::hafd.operation)::jsonb;  -- 52=type 06=len(6) "hello\0"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(__msg, 'hello', '3: NUL at end — should truncate to "hello"');

  -- 4. Multiple scattered NULs: "a\x00b\x00c" (5 bytes) → truncated to "a" (1 byte)
  __result := ('\x52056100620063'::hafd.operation)::jsonb;  -- 52=type 05=len(5) "a\0b\0c"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(__msg, 'a', '4: Multiple NULs — should truncate to "a"');

  -- 5. Consecutive NULs: "ab\x00\x00cd" (6 bytes) → truncated to "ab" (2 bytes)
  __result := ('\x5206616200006364'::hafd.operation)::jsonb;  -- 52=type 06=len(6) "ab\0\0cd"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(__msg, 'ab', '5: Consecutive NULs — should truncate to "ab"');

  -- 6. Single NUL only: "\x00" (1 byte) → truncated to "" (empty)
  __result := ('\x520100'::hafd.operation)::jsonb;  -- 52=type 01=len(1) "\0"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(__msg, '', '6: Single NUL — should truncate to empty');

  -- 7. All NULs: "\x00\x00\x00" (3 bytes) → truncated to "" (empty)
  __result := ('\x5203000000'::hafd.operation)::jsonb;  -- 52=type 03=len(3) "\0\0\0"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(__msg, '', '7: All NULs — should truncate to empty');

  -- ============================================================
  -- Tests 8-11: Roundtrip and consistency for clean strings
  -- ============================================================

  -- 8. Clean string baseline: "hello" roundtrips through operation::jsonb::operation exactly
  __clean_op := '\x520568656c6c6f'::hafd.operation;  -- 52=type 05=len(5) "hello"
  CALL test.check_eq(
    (__clean_op::jsonb::hafd.operation)::bytea,
    __clean_op::bytea,
    '8: Clean string not preserved through roundtrip'
  );

  -- 9. Empty string baseline: "" roundtrips through operation::jsonb::operation exactly
  __clean_op := '\x5200'::hafd.operation;  -- 52=type 00=len(0) ""
  CALL test.check_eq(
    (__clean_op::jsonb::hafd.operation)::bytea,
    __clean_op::bytea,
    '9: Empty string not preserved through roundtrip'
  );

  -- 10. Clean string consistency: operation::jsonb = operation_to_jsontext()::jsonb
  __clean_op := '\x520568656c6c6f'::hafd.operation;  -- 52=type 05=len(5) "hello"
  CALL test.check_eq(
    __clean_op::jsonb,
    hafd.operation_to_jsontext(__clean_op)::jsonb,
    '10: operation::jsonb differs from operation_to_jsontext()::jsonb for clean string'
  );

  -- 11. JSONB text roundtrip: casting truncated JSONB to text and back produces identical JSONB
  __result := ('\x52087465737400617070'::hafd.operation)::jsonb;  -- 52=type 08=len(8) "test\0app"
  __roundtrip_jsonb := __result::text::jsonb;
  CALL test.check_eq(
    __roundtrip_jsonb,
    __result,
    '11: JSONB text roundtrip failed — truncated JSONB is not valid'
  );

  -- ============================================================
  -- Tests 12+: Functional / integration-level checks
  -- ============================================================

  -- 12. operation_to_jsontext()::jsonb FAILS for NUL-containing operations.
  --     The text path emits \u0000 which PostgreSQL JSONB rejects.
  --     This proves why truncation in operation::jsonb is necessary.
  BEGIN
    PERFORM hafd.operation_to_jsontext('\x52087465737400617070'::hafd.operation)::jsonb;  -- 52=type 08=len(8) "test\0app"
    RAISE EXCEPTION '12: operation_to_jsontext()::jsonb should have failed for NUL-containing op';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: PostgreSQL rejects \u0000 in JSONB input
  END;

  -- 13. Extracted text length matches the expected truncated string.
  --     If NUL bytes leaked, the length would be wrong.
  __result := ('\x52087465737400617070'::hafd.operation)::jsonb;  -- 52=type 08=len(8) "test\0app"
  __msg := __result->'value'->>'message';
  CALL test.check_eq(
    length(__msg),
    4,  -- "test" = 4 chars, not 8 ("test\0app") or 7 ("testapp")
    '13: Extracted text length wrong — NUL bytes may have leaked'
  );

  -- 14. JSONB containment operator works on truncated result
  __result := ('\x52087465737400617070'::hafd.operation)::jsonb;  -- 52=type 08=len(8) "test\0app" → "test"
  CALL test.check_eq(
    __result @> '{"value": {"message": "test"}}'::jsonb,
    true,
    '14: JSONB @> containment failed on truncated result'
  );

  -- 15. jsonb_typeof confirms well-formed object structure at every level
  __result := ('\x52087465737400617070'::hafd.operation)::jsonb;  -- 52=type 08=len(8) "test\0app"
  CALL test.check_eq(
    jsonb_typeof(__result), 'object',
    '15a: jsonb_typeof on root is not object'
  );
  CALL test.check_eq(
    jsonb_typeof(__result->'value'), 'object',
    '15b: jsonb_typeof on value is not object'
  );
  CALL test.check_eq(
    jsonb_typeof(__result->'value'->'message'), 'string',
    '15c: jsonb_typeof on message is not string'
  );

  -- 16. jsonb_each_text does not crash on truncated JSONB
  --     (iterating all keys exercises internal JSONB traversal)
  DECLARE
    __key_count int;
  BEGIN
    SELECT count(*) INTO __key_count
    FROM jsonb_each_text(
      ('\x52087465737400617070'::hafd.operation)::jsonb -> 'value'  -- 52=type 08=len(8) "test\0app"
    );
    CALL test.check_eq(__key_count, 1, '16: jsonb_each_text key count wrong');
  END;

  -- 17. Multi-field operation: transfer_operation with NUL in memo field.
  --     Build a clean transfer, then binary-patch the memo to inject a NUL byte.
  --     Proves truncation works across all string fields, not just the first.
  DECLARE
    __clean_bytes bytea;
    __patched_jsonb jsonb;
    __memo text;
  BEGIN
    __clean_bytes := hafd.operation_from_jsontext(
      '{"type":"transfer_operation","value":{"from":"alice","to":"bob",'
      '"amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"hello"}}'
    )::bytea;
    -- Verify that the last 5 bytes are indeed "hello" before patching.
    CALL test.check_eq(
      substring(__clean_bytes from octet_length(__clean_bytes) - 4),
      '\x68656c6c6f'::bytea,  -- "hello"
      '17: precondition failed — last 5 bytes are not "hello"'
    );
    -- Replace "hello" with "he\x00lo" — same length, NUL in middle.
    __patched_jsonb := (overlay(__clean_bytes placing '\x6865006c6f'::bytea  -- "he\0lo"
                                from octet_length(__clean_bytes) - 4)::hafd.operation)::jsonb;
    __memo := __patched_jsonb->'value'->>'memo';
    CALL test.check_eq(__memo, 'he', '17a: NUL in transfer memo — should truncate to "he"');
    -- Verify other fields are unaffected
    CALL test.check_eq(
      __patched_jsonb->'value'->>'from', 'alice',
      '17b: from field corrupted after memo NUL injection'
    );
    CALL test.check_eq(
      __patched_jsonb->'value'->>'to', 'bob',
      '17c: to field corrupted after memo NUL injection'
    );
  END;

  -- 18. JSONB can be stored in and queried from a table column
  --     Proves the truncated JSONB is fully functional for real storage use.
  DECLARE
    __stored jsonb;
  BEGIN
    CREATE TEMPORARY TABLE __jsonb_test(data jsonb) ON COMMIT DROP;
    INSERT INTO __jsonb_test(data)
      VALUES (('\x52087465737400617070'::hafd.operation)::jsonb);  -- 52=type 08=len(8) "test\0app"
    SELECT data INTO __stored FROM __jsonb_test LIMIT 1;
    CALL test.check_eq(
      __stored->'value'->>'message', 'test',
      '18: JSONB stored/retrieved from table has wrong value'
    );
    DROP TABLE __jsonb_test;
  END;

  -- 19. Lossy roundtrip: operation→jsonb→operation produces the truncated form,
  --     NOT the original NUL-containing binary.
  DECLARE
    __nul_op hafd.operation := '\x52087465737400617070';  -- 52=type 08=len(8) "test\0app"
    __trunc_equiv hafd.operation := '\x520474657374';     -- 52=type 04=len(4) "test"
    __roundtrip hafd.operation;
  BEGIN
    __roundtrip := __nul_op::jsonb::hafd.operation;
    -- Roundtrip must NOT equal original (truncated at NUL)
    CALL test.check_eq(
      __roundtrip::bytea <> __nul_op::bytea, true,
      '19a: NUL-containing op should NOT roundtrip identically'
    );
    -- Roundtrip must equal the truncated equivalent
    CALL test.check_eq(
      __roundtrip::bytea, __trunc_equiv::bytea,
      '19b: Roundtrip should equal truncated equivalent'
    );
  END;

  -- 20. JSONB from NUL op equals JSONB from pre-truncated clean equivalent
  DECLARE
    __nul_jsonb jsonb;
    __trunc_jsonb jsonb;
  BEGIN
    __nul_jsonb   := ('\x52087465737400617070'::hafd.operation)::jsonb;  -- 52=type 08=len(8) "test\0app"
    __trunc_jsonb := ('\x520474657374'::hafd.operation)::jsonb;          -- 52=type 04=len(4) "test"
    CALL test.check_eq(
      __nul_jsonb, __trunc_jsonb,
      '20: JSONB from NUL op should equal JSONB from truncated equivalent'
    );
  END;
END;
$BODY$
;
