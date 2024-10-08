CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.disable_indexes_of_reversible();
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
        WHERE tc.table_schema='hive' AND tc.table_name=_table_name AND tc.constraint_type = 'FOREIGN KEY'
        ) INTO __result;
    RETURN __result;
END;
$BODY$
;

SELECT * FROM information_schema.table_constraints WHERE table_schema='hive' AND table_name='contexts' AND constraint_type = 'FOREIGN KEY' LIMIT 1;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.blocks_reversible'::regclass::oid ) ) , 'Index hive_data.blocks exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.transactions_reversible'::regclass::oid ) ) , 'Index hive_data.transactions exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.operations_reversible'::regclass::oid ) ) , 'Index hive_data.operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.transactions_multisig_reversible'::regclass::oid ) ) , 'Index hive_data.transactions_multisig exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.accounts_reversible'::regclass::oid ) ) , 'Index hive_data.accounts exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.account_operations_reversible'::regclass::oid ) ) , 'Index hive_data.account_operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.applied_hardforks_reversible'::regclass::oid ) ) , 'Index hive_data.applied_hardforks exists';

    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'blocks_reversible') ), 'FK for hive_data.blocks exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions_reversible') ), 'FK for hive_data.transactions exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'operations_reversible') ), 'FK for hive_data.operations exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig_reversible') ), 'FK for hive_data.transactions_multisig exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'irreversible_data_reversible') ), 'FK for hive_data.irreversible_data exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'accounts_reversible') ), 'FK for hive_data.accounts exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'account_operations_reversible') ), 'FK for hive_data.account_operations exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'applied_hardforks_reversible') ), 'FK for hive_data.applied_hardforks exists';


    ASSERT EXISTS(
        SELECT * FROM hive_data.indexes_constraints WHERE table_name='hive_data.transactions_multisig_reversible'
        AND command LIKE 'ALTER TABLE hive_data.transactions_multisig_reversible ADD CONSTRAINT fk_1_hive_transactions_multisig_reversible FOREIGN KEY (trx_hash, fork_id) REFERENCES hive_data.transactions_reversible(trx_hash, fork_id)'
    ), 'No hive_data.operation index (block_num, id)';
END;
$BODY$
;
