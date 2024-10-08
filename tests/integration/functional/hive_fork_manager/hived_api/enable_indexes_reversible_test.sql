
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.disable_indexes_of_reversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
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
    AS
$BODY$
DECLARE
__result bool;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        WHERE tc.table_schema='hive_data' AND tc.table_name=_table_name AND tc.constraint_type = 'FOREIGN KEY'
        ) INTO __result;
    RETURN __result;
END;
$BODY$
;

DROP FUNCTION IF EXISTS is_constraint_exists;
CREATE FUNCTION is_constraint_exists( _name TEXT, _type TEXT )
    RETURNS bool
    LANGUAGE 'plpgsql'
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

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT is_any_index_for_table( 'hive_data.blocks_reversible'::regclass::oid ) ) , 'Index hive_data.blocks not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive_data.transactions_reversible'::regclass::oid ) ) , 'Index hive_data.transactions not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive_data.operations_reversible'::regclass::oid ) ) , 'Index hive_data.operations not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive_data.transactions_multisig_reversible'::regclass::oid ) ) , 'Index hive_data.transactions_multisig not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive_data.accounts_reversible'::regclass::oid ) ) , 'Index hive_data.accounts_reversible not exists';



    ASSERT ( SELECT is_any_fk_for_hive_table( 'blocks_reversible') ), 'FK for hive_data.blocks_reversible not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'transactions_reversible') ), 'FK for hive_data.transactions not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig_reversible') ), 'FK for hive_data.transactions_multisig not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'account_operations_reversible') ), 'FK for hive_data.account_operations not exists';
    ASSERT ( SELECT is_any_fk_for_hive_table( 'accounts_reversible') ), 'FK for hive_data.accounts not exists';



END;
$BODY$
;
