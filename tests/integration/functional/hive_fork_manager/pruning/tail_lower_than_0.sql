CREATE OR REPLACE PROCEDURE test_hived_test_error()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.prune_blocks_data(-1);
END;
$BODY$
;