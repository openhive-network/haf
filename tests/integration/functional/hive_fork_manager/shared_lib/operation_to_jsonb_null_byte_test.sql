-- Test for issue #319: Buffer over-read in push_string_to_jsonb when string contains embedded \x00
--
-- pstrdup truncates at \x00 but len reflects full std::string length, causing a heap buffer
-- over-read in pushJsonbValue. The fix uses a length-aware copy (memcpy with value.data())
-- to faithfully preserve ALL bytes of the original string, including embedded nulls.
-- HAF must never alter data delivered by hived.
--
-- system_warning_operation with message "test\x00app" (8 bytes with embedded null):
-- Binary encoding: 0x52 (type) + 0x08 (varint length=8) + "test\x00app"

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
  __original hafd.operation := '\x52087465737400617070';
  __roundtrip hafd.operation;
BEGIN
  -- Roundtrip: operation -> jsonb -> operation must produce identical binary.
  -- This proves the JSONB faithfully represents the operation with zero data loss.
  -- Before the fix, pstrdup copied only 4 bytes ("test") but len was set to 8,
  -- so pushJsonbValue read 4 bytes of uninitialized heap memory into the JSONB,
  -- corrupting the roundtrip result.
  __roundtrip := __original::jsonb::hafd.operation;

  CALL test.check_eq(
    __roundtrip::bytea,
    __original::bytea,
    'operation with embedded null byte is not preserved through operation::jsonb::operation roundtrip'
  );
END;
$BODY$
;
