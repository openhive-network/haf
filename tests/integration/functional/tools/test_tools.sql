SELECT hive.initialize_extension_data();

CREATE OR REPLACE FUNCTION hive.unordered_arrays_equal(arr1 TEXT[], arr2 TEXT[])
RETURNS bool
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
    return (arr1 <@ arr2 and arr1 @> arr2);
END
$$
;

CREATE PROCEDURE hive.check_eq(a anyelement, b anyelement, msg text DEFAULT 'Expected to be equal, but failed')
LANGUAGE plpgsql
AS
$BODY$
BEGIN
  IF a <> b THEN
    assert (SELECT FALSE), FORMAT(E'%s:\na: %s\nb: %s', msg, a, b);
  END IF;
END;
$BODY$
;

CREATE FUNCTION hive.is_index_exists(_schema TEXT, _table_name TEXT, _index_name TEXT)
RETURNS BOOL
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  __result bool;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = _schema AND tablename = _table_name AND indexname = _index_name
  ) INTO __result;
  RETURN __result;
END;
$BODY$;
