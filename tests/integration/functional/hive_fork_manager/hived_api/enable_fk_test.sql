-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- Must enable indexes first to restore PKs before FKs can be added
    PERFORM hive.enable_indexes_of_irreversible();
    PERFORM hive.enable_fk_of_irreversible();
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
        WHERE tc.table_schema='hafd' AND tc.table_name=_table_name AND tc.constraint_type = 'FOREIGN KEY'
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
    -- In the new schema, data tables (transactions, transactions_multisig, applied_hardforks)
    -- no longer have foreign key constraints. The block_id encoding replaces the need for FKs.
    -- Verify that the enable_fk_of_irreversible function completed without error.
    -- Since there are no FKs to restore, we just verify the operation succeeded.

    -- Verify indexes were restored (PKs are needed for data integrity)
    ASSERT ( SELECT is_any_index_for_table( 'hafd.transactions'::regclass::oid ) ) , 'Index hafd.transactions not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hafd.transactions_multisig'::regclass::oid ) ) , 'Index hafd.transactions_multisig not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hafd.applied_hardforks'::regclass::oid ) ) , 'Index hafd.applied_hardforks not exists';

    -- Verify primary key constraints exist
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_transactions', 'PRIMARY KEY' ) ), 'PK pk_hive_transactions not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_transactions_multisig', 'PRIMARY KEY' ) ), 'PK pk_hive_transactions_multisig not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_applied_hardforks', 'PRIMARY KEY' ) ), 'PK pk_hive_applied_hardforks not exists';

END;
$BODY$
;
