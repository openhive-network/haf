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

CREATE OR REPLACE FUNCTION hive.get_operation_id( block_num INT, op_type_id INT, number_in_block INT )
    RETURNS BIGINT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN ( block_num::BIGINT << 32 ) | ( op_type_id << 24 ) | ( number_in_block );
END;
$BODY$
;

