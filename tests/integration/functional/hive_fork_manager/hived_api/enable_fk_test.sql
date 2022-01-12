DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.enable_fk_of_irreversible();
END;
$BODY$
;

DROP FUNCTION IF EXISTS is_any_index_for_table;
CREATE FUNCTION is_any_index_for_table( _table OID )
    RETURNS bool
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
DECLARE
    __result bool;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM pg_index ix, pg_attribute a
        WHERE ix.indrelid = _table
        AND a.attrelid = _table
        AND a.attnum = ANY(ix.indkey)
    ) INTO __result;
    RETURN __result;
END;
$BODY$
;


DROP FUNCTION IF EXISTS is_any_fk_for_hive_table;
CREATE FUNCTION is_any_fk_for_hive_table( _table_name TEXT )
    RETURNS bool
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
DECLARE
__result bool;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        WHERE tc.table_schema='hive' AND tc.table_name=_table_name AND tc.constraint_type = 'FOREIGN KEY'
        ) INTO __result;
    RETURN __result;
END;
$BODY$
;

DROP FUNCTION IF EXISTS is_constraint_exists;
CREATE FUNCTION is_constraint_exists( _name TEXT, _type TEXT )
    RETURNS bool
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
DECLARE
__result bool;
BEGIN
SELECT EXISTS (
               SELECT 1 FROM information_schema.table_constraints tc
               WHERE tc.constraint_name = _name AND tc.constraint_type = _type
           ) INTO __result;
RETURN __result;
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT is_any_fk_for_hive_table( 'transactions') ), 'FK for hive.transactions not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'operations') ), 'FK for hive.operations not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig') ), 'FK for hive.transactions_multisig not exists';

    ASSERT ( SELECT is_constraint_exists( 'fk_1_hive_transactions', 'FOREIGN KEY' ) ), 'FK fk_1_hive_transactions not exists';
    ASSERT ( SELECT is_constraint_exists( 'fk_1_hive_transactions_multisig', 'FOREIGN KEY' ) ), 'FK fk_1_hive_transactions_multisig not exists';
    ASSERT ( SELECT is_constraint_exists( 'fk_1_hive_operations', 'FOREIGN KEY' ) ), 'FK fk_1_hive_operations not exists';
    ASSERT ( SELECT is_constraint_exists( 'fk_2_hive_operations', 'FOREIGN KEY' ) ), 'FK fk_2_hive_operations not exists';
    ASSERT ( SELECT is_constraint_exists( 'fk_1_hive_irreversible_data', 'FOREIGN KEY' ) ), 'FK fk_1_hive_irreversible_data not exists';
END;
$BODY$
;
