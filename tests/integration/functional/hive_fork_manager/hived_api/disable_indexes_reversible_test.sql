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
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.blocks_reversible'::regclass::oid ) ) , 'Index hafd.blocks exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.transactions_reversible'::regclass::oid ) ) , 'Index hafd.transactions exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.operations_reversible'::regclass::oid ) ) , 'Index hafd.operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.transactions_multisig_reversible'::regclass::oid ) ) , 'Index hafd.transactions_multisig exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.accounts_reversible'::regclass::oid ) ) , 'Index hafd.accounts exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.account_operations_reversible'::regclass::oid ) ) , 'Index hafd.account_operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.applied_hardforks_reversible'::regclass::oid ) ) , 'Index hafd.applied_hardforks exists';

    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'blocks_reversible') ), 'FK for hafd.blocks exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions_reversible') ), 'FK for hafd.transactions exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'operations_reversible') ), 'FK for hafd.operations exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig_reversible') ), 'FK for hafd.transactions_multisig exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'irreversible_data_reversible') ), 'FK for hafd.hive_state exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'accounts_reversible') ), 'FK for hafd.accounts exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'account_operations_reversible') ), 'FK for hafd.account_operations exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'applied_hardforks_reversible') ), 'FK for hafd.applied_hardforks exists';


    ASSERT EXISTS(
        SELECT * FROM hafd.indexes_constraints WHERE table_name='hafd.transactions_multisig_reversible'
        AND command LIKE 'ALTER TABLE hafd.transactions_multisig_reversible ADD CONSTRAINT fk_1_hive_transactions_multisig_reversible FOREIGN KEY (trx_hash, fork_id) REFERENCES hafd.transactions_reversible(trx_hash, fork_id)'
    ), 'No hafd.operation index (block_num, id)';
END;
$BODY$
;
