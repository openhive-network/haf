CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  -- NULL input returns NULL (STRICT)
  ASSERT hive.strip_json_null_escapes(NULL) IS NULL,
    'NULL input should return NULL';

  -- No \u0000: input returned unchanged
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"key": "value"}'),
    '{"key": "value"}',
    'text without \u0000 should pass through unchanged'
  );

  -- Bare \u0000 is stripped
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"k": "test\u0000test"}'),
    '{"k": "testtest"}',
    'bare \u0000 should be stripped'
  );

  -- Multiple bare \u0000 are all stripped
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"k": "a\u0000b\u0000c"}'),
    '{"k": "abc"}',
    'multiple bare \u0000 should all be stripped'
  );

  -- \\u0000 (escaped backslash + literal u0000) is preserved
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"k": "test\\u0000test"}'),
    '{"k": "test\\u0000test"}',
    '\\u0000 (escaped backslash) should be preserved'
  );

  -- \\\u0000 = escaped backslash + bare \u0000: backslash kept, \u0000 stripped
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"k": "test\\\u0000test"}'),
    '{"k": "test\\test"}',
    '\\\u0000 should keep \\ and strip \u0000'
  );

  -- \\\\u0000 = two escaped backslashes + literal u0000: all preserved
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"k": "test\\\\u0000test"}'),
    '{"k": "test\\\\u0000test"}',
    '\\\\u0000 (two escaped backslashes) should be preserved'
  );

  -- Real-world case: Java regex from block 14,159,292
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"body": "replaceAll(\"[\\u0000-\\u001f]\", \"\")"}'),
    '{"body": "replaceAll(\"[\\u0000-\\u001f]\", \"\")"}',
    'Java regex \\u0000 in post body should be preserved'
  );

  -- Real-world case: block 104,130,768 guest4test json_metadata
  -- The json_metadata string contains inner JSON with \u0000 escapes.
  -- After ->> extraction, these appear as bare \u0000 in the text.
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"tags":["spam","test\u0000test\u0000"],"author":"\u0000"}'),
    '{"tags":["spam","testtest"],"author":""}',
    'guest4test json_metadata \u0000 should be stripped'
  );

  -- Empty string
  CALL test.check_eq(
    hive.strip_json_null_escapes(''),
    '',
    'empty string should return empty'
  );

  -- \u0000 at start and end
  CALL test.check_eq(
    hive.strip_json_null_escapes('\u0000hello\u0000'),
    'hello',
    '\u0000 at boundaries should be stripped'
  );

  -- Only \u0000
  CALL test.check_eq(
    hive.strip_json_null_escapes('\u0000'),
    '',
    'string that is only \u0000 should become empty'
  );

  -- \u0001 and other escapes are NOT touched
  CALL test.check_eq(
    hive.strip_json_null_escapes('{"k": "test\u0001\u0000end"}'),
    '{"k": "test\u0001end"}',
    'only \u0000 is stripped, other unicode escapes preserved'
  );
END;
$BODY$
;
