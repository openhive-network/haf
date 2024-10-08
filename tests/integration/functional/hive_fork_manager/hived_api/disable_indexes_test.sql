
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
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
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.blocks'::regclass::oid ) ) , 'Index hive_data.blocks exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.transactions'::regclass::oid ) ) , 'Index hive_data.transactions exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.operations'::regclass::oid ) ) , 'Index hive_data.operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.transactions_multisig'::regclass::oid ) ) , 'Index hive_data.transactions_multisig exists';
    -- hive_data.irreversible_data pk must exist because ON CONFLICT is used during restarting HAF node
    ASSERT ( SELECT is_any_index_for_table( 'hive_data.irreversible_data'::regclass::oid ) ) , 'Index hive_data.irreversible_data does not exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.accounts'::regclass::oid ) ) , 'Index hive_data.accounts exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.account_operations'::regclass::oid ) ) , 'Index hive_data.account_operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hive_data.applied_hardforks'::regclass::oid ) ) , 'Index hive_data.applied_hardforks exists';


    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'blocks') ), 'FK for hive_data.blocks exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions') ), 'FK for hive_data.transactions exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig') ), 'FK for hive_data.transactions_multisig exists';
    -- we need to disable hive_data.irreversible_data fk because its dependency with hive_data.blocks
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'irreversible_data') ), 'FK for hive_data.irreversible_data exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'accounts') ), 'FK for hive_data.accounts exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'account_operations') ), 'FK for hive_data.account_operations exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'applied_hardforks') ), 'FK for hive_data.applied_hardforks exists';


    ASSERT EXISTS(
        SELECT * FROM hive_data.indexes_constraints WHERE table_name='hive_data.operations' AND command LIKE 'CREATE INDEX hive_operations_block_num_id_idx ON hive_data.operations USING btree (hive.operation_id_to_block_num(id), id)'
    ), 'No hive_data.operation index (block_num, id)';

    ASSERT EXISTS(
        SELECT * FROM hive_data.indexes_constraints WHERE table_name='hive_data.account_operations' AND command LIKE 'ALTER TABLE hive_data.account_operations ADD CONSTRAINT hive_account_operations_uq1 UNIQUE (account_id, account_op_seq_no)'
    ), 'No hive_data.account_operations unique (account_id, account_op_seq_no)';

END;
$BODY$
;
