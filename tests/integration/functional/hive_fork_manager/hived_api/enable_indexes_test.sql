
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
    PERFORM hive.enable_indexes_of_irreversible();
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
    ASSERT ( SELECT is_any_index_for_table( 'hafd.blocks'::regclass::oid ) ) , 'Index hafd.blocks not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hafd.transactions'::regclass::oid ) ) , 'Index hafd.transactions not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hafd.operations'::regclass::oid ) ) , 'Index hafd.operations not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hafd.transactions_multisig'::regclass::oid ) ) , 'Index hafd.transactions_multisig not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hafd.applied_hardforks'::regclass::oid ) ) , 'Index hafd.applied_hardforks not exists';


    ASSERT ( SELECT is_constraint_exists( 'pk_hive_blocks', 'PRIMARY KEY' ) ), 'PK pk_hive_blocks not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_transactions', 'PRIMARY KEY' ) ), 'PK pk_hive_transactions not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_transactions_multisig', 'PRIMARY KEY' ) ), 'PK pk_hive_transactions_multisig not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_operations', 'PRIMARY KEY' ) ), 'PK pk_hive_operations not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_irreversible_data', 'PRIMARY KEY' ) ), 'PK pk_hive_irreversible_data not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_applied_hardforks', 'PRIMARY KEY' ) ), 'PK pk_hive_applied_hardforks not exists';


    ASSERT EXISTS( SELECT 1 FROM pg_index pgi WHERE pgi.indrelid = 'hafd.transactions'::regclass::oid ), 'No index for table hafd.transactions';
    ASSERT EXISTS( SELECT 1 FROM pg_index pgi WHERE pgi.indrelid = 'hafd.operations'::regclass::oid ), 'No index for table hafd.operations';
END;
$BODY$
;
