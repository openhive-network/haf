DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.disable_indexes_of_reversible();
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.enable_indexes_of_reversible();
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

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT is_any_index_for_table( 'hive.blocks_reversible'::regclass::oid ) ) , 'Index hive.blocks not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.transactions_reversible'::regclass::oid ) ) , 'Index hive.transactions not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.operations_reversible'::regclass::oid ) ) , 'Index hive.operations not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.transactions_multisig_reversible'::regclass::oid ) ) , 'Index hive.transactions_multisig not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.accounts_reversible'::regclass::oid ) ) , 'Index hive.accounts_reversible not exists';



    ASSERT ( SELECT is_any_fk_for_hive_table( 'blocks_reversible') ), 'FK for hive.blocks_reversible not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'transactions_reversible') ), 'FK for hive.transactions not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'operations_reversible') ), 'FK for hive.operations not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig_reversible') ), 'FK for hive.transactions_multisig not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'account_operations_reversible') ), 'FK for hive.account_operations not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'accounts_reversible') ), 'FK for hive.accounts not exists';



END;
$BODY$
;
