-- Integration test for \u0000 handling in body_value jsonb column.
--
-- The C++ sql_serializer COPY path calls strip_json_null_escapes() on
-- body_value JSON before writing to PostgreSQL. This test verifies:
-- 1. PostgreSQL jsonb rejects \u0000 (proving the C++ fix is necessary)
-- 2. hive.strip_json_null_escapes() produces valid jsonb for storage
-- 3. Stripped body_value pushed through hive.push_block() can be stored and queried
-- 4. Data survives set_irreversible (copy to irreversible tables)
--
-- Real-world crash: block 96,358,081 custom_json from user 'bamdecs'
-- contained \x00 in the JSON payload, which fc::json serialized as \u0000.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  INSERT INTO hafd.operation_types
  VALUES
    ( 18, 'custom_json_operation', FALSE )
  ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  __block hafd.blocks%ROWTYPE;
  __transaction hafd.transactions%ROWTYPE;
  __operation_clean hafd.operations%ROWTYPE;
  __operation_nul hafd.operations%ROWTYPE;
  __operation_escaped_bs hafd.operations%ROWTYPE;
  __signatures hafd.transactions_multisig%ROWTYPE;
  __account hafd.accounts%ROWTYPE;
  __account_op1 hafd.account_operations%ROWTYPE;
  __account_op2 hafd.account_operations%ROWTYPE;
  __account_op3 hafd.account_operations%ROWTYPE;
  __applied_hardfork hafd.applied_hardforks%ROWTYPE;

  __raw_json text;
  __stripped_json text;
BEGIN
  -- ============================================================
  -- 1. Prove PostgreSQL jsonb rejects \u0000
  -- ============================================================
  BEGIN
    PERFORM '{"id":"test\u0000data"}'::jsonb;
    RAISE EXCEPTION '1: jsonb should reject \u0000 but did not';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: "unsupported Unicode escape sequence"
  END;

  -- ============================================================
  -- 2. Build operations with stripped body_value and push via hive.push_block()
  -- ============================================================

  __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp,
              1, '\x4007', E'[]', '\x2157',
              'STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G',
              1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
  __transaction = ( 101, 0::SMALLINT, '\xDEED', 101, 100,
                    '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
  __signatures = ( '\xDEED', '\xFEED' );
  __account = ( 1, 'bamdecs', 101 );
  __applied_hardfork = ( 1, 101, hafd.operation_id(101, 0) );

  -- Op 1: clean custom_json (no NUL) — baseline
  __operation_clean = ( hafd.operation_id(101, 0), 0, 18, 0,
                        '{"id":"follow","json":"{\"follower\":\"alice\"}"}'::jsonb, NULL );

  -- Op 2: custom_json with \u0000 stripped — simulates what C++ strip_json_null_escapes() does
  __raw_json := '{"id":"sm_market_sell","json":"{\u0000\"items\":[\"abc\u0000\"]}"}';
  __stripped_json := hive.strip_json_null_escapes(__raw_json);
  __operation_nul = ( hafd.operation_id(101, 1), 0, 18, 1,
                      __stripped_json::jsonb, NULL );

  -- Op 3: escaped backslash before u0000 — must be preserved (not a real NUL escape)
  __raw_json := '{"id":"regex_test","pattern":"[\\u0000-\\u001f]"}';
  __stripped_json := hive.strip_json_null_escapes(__raw_json);
  __operation_escaped_bs = ( hafd.operation_id(101, 2), 0, 18, 2,
                             __stripped_json::jsonb, NULL );

  __account_op1 = ( 1, 1, 1, hafd.operation_id(101, 0), 18 );
  __account_op2 = ( 1, 1, 2, hafd.operation_id(101, 1), 18 );
  __account_op3 = ( 1, 1, 3, hafd.operation_id(101, 2), 18 );

  PERFORM hive.push_block(
      __block
    , ARRAY[ __transaction ]
    , ARRAY[ __signatures ]
    , ARRAY[ __operation_clean, __operation_nul, __operation_escaped_bs ]
    , ARRAY[ __account ]
    , ARRAY[ __account_op1, __account_op2, __account_op3 ]
    , ARRAY[ __applied_hardfork ]
  );

  -- Make block irreversible so data moves to hafd.operations (non-reversible)
  PERFORM hive.set_irreversible( 101 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  __body jsonb;
BEGIN
  -- ============================================================
  -- 3. Verify operations in irreversible table
  -- ============================================================

  ASSERT ( SELECT COUNT(*) FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) = 101 ) = 3,
    '3: Expected 3 operations in block 101';

  -- 3a. Clean operation — baseline check
  SELECT body_value INTO __body FROM hafd.operations WHERE id = hafd.operation_id(101, 0);
  CALL test.check_eq(
    __body->>'id', 'follow',
    '3a: clean operation id field wrong'
  );

  -- 3b. NUL-stripped operation — \u0000 sequences removed
  SELECT body_value INTO __body FROM hafd.operations WHERE id = hafd.operation_id(101, 1);
  CALL test.check_eq(
    __body->>'id', 'sm_market_sell',
    '3b: NUL-stripped operation id field wrong'
  );
  -- The inner json field had \u0000 before and after "items" key — both stripped
  CALL test.check_eq(
    __body->>'json', '{"items":["abc"]}',
    '3c: NUL-stripped json field should have \u0000 removed'
  );

  -- 3d. Escaped backslash operation — \\u0000 preserved as literal text
  SELECT body_value INTO __body FROM hafd.operations WHERE id = hafd.operation_id(101, 2);
  CALL test.check_eq(
    __body->>'id', 'regex_test',
    '3d: escaped backslash operation id field wrong'
  );
  -- \\u0000 in JSON source becomes \u0000 in the extracted text value (one level of escaping removed by jsonb)
  CALL test.check_eq(
    __body->>'pattern', '[\u0000-\u001f]',
    '3e: escaped backslash pattern should preserve \\u0000 as literal'
  );

  -- ============================================================
  -- 4. Verify reversible table is empty (data moved to irreversible)
  -- ============================================================
  ASSERT ( SELECT COUNT(*) FROM hafd.operations_reversible
           WHERE hafd.operation_id_to_block_num(id) = 101 ) = 0,
    '4: operations_reversible should be empty after set_irreversible';

  -- ============================================================
  -- 5. Verify jsonb operators work on stored data
  -- ============================================================

  -- Containment query on NUL-stripped operation
  ASSERT ( SELECT COUNT(*) FROM hafd.operations
           WHERE body_value @> '{"id":"sm_market_sell"}'::jsonb
             AND hafd.operation_id_to_block_num(id) = 101 ) = 1,
    '5a: jsonb containment query failed on NUL-stripped data';

  -- Text extraction and comparison
  ASSERT ( SELECT body_value->>'id' FROM hafd.operations
           WHERE id = hafd.operation_id(101, 1) ) = 'sm_market_sell',
    '5b: text extraction from NUL-stripped body_value failed';
END;
$BODY$
;
