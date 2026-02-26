-- Test for issue #319: NUL bytes (\x00) in JSONB string conversion
--
-- PROBLEM (heap buffer over-read):
-- push_string_to_jsonb() used pstrdup(value.c_str()) which calls strlen() internally
-- and stops at the first \x00 byte.  But jb.val.string.len was set to
-- std::string::length(), which counts ALL bytes including embedded NULs.
-- pushJsonbValue then read past the allocated buffer — a heap buffer over-read.
--
-- FIX: pstrdup_with_len() uses memcpy with value.data() and value.length(),
-- faithfully preserving ALL bytes of the original string including embedded NULs.
-- HAF must never alter data delivered by hived.
--
-- All test cases use system_warning_operation (type tag 0x52, id 82) which has
-- a single field:  message text
-- Binary layout:  0x52 <varint message-length> <message bytes>

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
  __original hafd.operation;
  __roundtrip hafd.operation;
BEGIN
  -------------------------------------------------------------------
  -- 1. NUL in the middle:  "test\x00app"  (8 bytes)
  --    0x52 08 74 65 73 74 00 61 70 70
  -------------------------------------------------------------------
  __original := '\x52087465737400617070';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '1: NUL in the middle — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 2. NUL at the start:  "\x00hello"  (6 bytes)
  --    0x52 06 00 68 65 6c 6c 6f
  -------------------------------------------------------------------
  __original := '\x52060068656c6c6f';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '2: NUL at start — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 3. NUL at the end:  "hello\x00"  (6 bytes)
  --    0x52 06 68 65 6c 6c 6f 00
  -------------------------------------------------------------------
  __original := '\x520668656c6c6f00';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '3: NUL at end — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 4. Multiple NULs scattered:  "a\x00b\x00c"  (5 bytes)
  --    0x52 05 61 00 62 00 63
  -------------------------------------------------------------------
  __original := '\x52056100620063';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '4: scattered NULs — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 5. Consecutive NULs:  "ab\x00\x00cd"  (6 bytes)
  --    0x52 06 61 62 00 00 63 64
  -------------------------------------------------------------------
  __original := '\x5206616200006364';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '5: consecutive NULs — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 6. Only NUL:  "\x00"  (1 byte)
  --    0x52 01 00
  -------------------------------------------------------------------
  __original := '\x520100';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '6: single NUL byte — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 7. All NULs:  "\x00\x00\x00"  (3 bytes)
  --    0x52 03 00 00 00
  -------------------------------------------------------------------
  __original := '\x5203000000';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '7: all-NUL bytes — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 8. No NUL (baseline):  "hello"  (5 bytes)
  --    0x52 05 68 65 6c 6c 6f
  -------------------------------------------------------------------
  __original := '\x520568656c6c6f';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '8: clean string baseline — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 9. Empty string (baseline):  ""  (0 bytes)
  --    0x52 00
  -------------------------------------------------------------------
  __original := '\x5200';
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea, __original::bytea,
    '9: empty string baseline — roundtrip corrupted'
  );

  -------------------------------------------------------------------
  -- 10. Direct cast (operation::jsonb) vs indirect (operation::text::jsonb)
  --     must agree on clean strings.
  -------------------------------------------------------------------
  __original := '\x520568656c6c6f';
  CALL test.check_eq(
    __original::jsonb,
    hafd.operation_to_jsontext(__original)::jsonb,
    '10: operation::jsonb vs operation::text::jsonb mismatch on clean string'
  );
END;
$BODY$
;
