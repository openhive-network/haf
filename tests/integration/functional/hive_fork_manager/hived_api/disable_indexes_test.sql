
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
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.blocks'::regclass::oid ) ) , 'Index hafd.blocks exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.transactions'::regclass::oid ) ) , 'Index hafd.transactions exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.operations'::regclass::oid ) ) , 'Index hafd.operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.transactions_multisig'::regclass::oid ) ) , 'Index hafd.transactions_multisig exists';
    -- hafd.hive_state pk must exist because ON CONFLICT is used during restarting HAF node
    ASSERT ( SELECT is_any_index_for_table( 'hafd.hive_state'::regclass::oid ) ) , 'Index hafd.hive_state does not exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.accounts'::regclass::oid ) ) , 'Index hafd.accounts exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.account_operations'::regclass::oid ) ) , 'Index hafd.account_operations exists';
    ASSERT NOT ( SELECT is_any_index_for_table( 'hafd.applied_hardforks'::regclass::oid ) ) , 'Index hafd.applied_hardforks exists';


    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'blocks') ), 'FK for hafd.blocks exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions') ), 'FK for hafd.transactions exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'transactions_multisig') ), 'FK for hafd.transactions_multisig exists';
    -- we need to disable hafd.hive_state fk because its dependency with hafd.blocks
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'hive_state') ), 'FK for hafd.hive_state exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'accounts') ), 'FK for hafd.accounts exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'account_operations') ), 'FK for hafd.account_operations exists';
    ASSERT NOT ( SELECT is_any_fk_for_hive_table( 'applied_hardforks') ), 'FK for hafd.applied_hardforks exists';


    ASSERT EXISTS(
        SELECT * FROM hafd.indexes_constraints WHERE table_name='hafd.operations' AND command LIKE 'CREATE INDEX hive_operations_block_num_id_idx ON hafd.operations USING btree (hafd.operation_id_to_block_num(id), id)'
    ), 'No hafd.operation index (block_num, id)';

    ASSERT EXISTS(
        SELECT * FROM hafd.indexes_constraints WHERE table_name='hafd.account_operations' AND command LIKE 'CREATE UNIQUE INDEX hive_account_operations_account_id_op_type_id_idx ON hafd.account_operations USING btree (account_id, account_op_seq_no DESC, hafd.operation_id_to_type_id(operation_id))'
    ), 'No hafd.account_operations unique (account_id, transacting_account_id, op_type_id)';

END;
$BODY$
;
