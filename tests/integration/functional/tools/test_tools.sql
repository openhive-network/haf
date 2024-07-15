SELECT hive.initialize_extension_data();

CREATE OR REPLACE FUNCTION hive.unordered_arrays_equal(arr1 hive.ctext[], arr2 hive.ctext[])
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

CREATE PROCEDURE hive.check_eq(a anyelement, b anyelement, msg hive.ctext DEFAULT 'Expected to be equal, but failed')
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

