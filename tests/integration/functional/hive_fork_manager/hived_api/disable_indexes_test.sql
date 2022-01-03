DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- nothing to do here
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
    PERFORM hive.disable_indexes_of_irreversible();
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

SELECT * FROM information_schema.table_constraints WHERE table_schema='hive' AND table_name='contexts' AND constraint_type = 'FOREIGN KEY' LIMIT 1;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive.blocks'::regclass::oid ) ) , 'Index hive.blocks exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive.transactions'::regclass::oid ) ) , 'Index hive.transactions exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive.operations'::regclass::oid ) ) , 'Index hive.operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive.transactions_multisig'::regclass::oid ) ) , 'Index hive.transactions_multisig exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive.irreversible_data'::regclass::oid ) ) , 'Index hive.irreversible_data exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive.accounts'::regclass::oid ) ) , 'Index hive.accounts exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive.account_operations'::regclass::oid ) ) , 'Index hive.account_operations exists';

    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'blocks') ), 'FK for hive.blocks exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions') ), 'FK for hive.transactions exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'operations') ), 'FK for hive.operations exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig') ), 'FK for hive.transactions_multisig exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'irreversible_data') ), 'FK for hive.irreversible_data exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'accounts') ), 'FK for hive.accounts exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'account_operations') ), 'FK for hive.account_operations exists';

    ASSERT EXISTS(
        SELECT * FROM hive.indexes_constraints WHERE table_name='hive.operations' AND command LIKE 'CREATE INDEX hive_operations_block_num_id_idx ON hive.operations USING btree (block_num, id)'
    ), 'No hive.operation index (block_num, id)';

    ASSERT EXISTS(
        SELECT * FROM hive.indexes_constraints WHERE table_name='hive.account_operations' AND command LIKE 'ALTER TABLE hive.account_operations ADD CONSTRAINT hive_account_operations_uq_1 UNIQUE (account_id, account_op_seq_no)'
    ), 'No hive.account_operations unique (account_id, account_op_seq_no)';

END;
$BODY$
;
