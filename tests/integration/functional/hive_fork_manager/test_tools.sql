INSERT INTO hive.irreversible_data VALUES(1,NULL, FALSE) ON CONFLICT DO NOTHING;


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
