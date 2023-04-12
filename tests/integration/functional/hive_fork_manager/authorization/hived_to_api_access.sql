DROP FUNCTION IF EXISTS hived_test_then;
CREATE FUNCTION hived_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();
    PERFORM hive.enable_indexes_of_irreversible();
    PERFORM hive.enable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_reversible();
    PERFORM hive.enable_indexes_of_reversible();
    PERFORM hive.connect( 'sha', 0 );
    PERFORM hive.set_irreversible_dirty();
    PERFORM hive.set_irreversible_not_dirty();
    PERFORM hive.is_irreversible_dirty();
END;
$BODY$
;
