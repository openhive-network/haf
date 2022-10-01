DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();
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
    PERFORM hive.enable_indexes_of_irreversible();
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
    ASSERT ( SELECT is_any_index_for_table( 'hive.blocks'::regclass::oid ) ) , 'Index hive.blocks not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.transactions'::regclass::oid ) ) , 'Index hive.transactions not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.operations'::regclass::oid ) ) , 'Index hive.operations not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.transactions_multisig'::regclass::oid ) ) , 'Index hive.transactions_multisig not exists';
    ASSERT ( SELECT is_any_index_for_table( 'hive.applied_hardforks'::regclass::oid ) ) , 'Index hive.applied_hardforks not exists';


    ASSERT ( SELECT is_constraint_exists( 'pk_hive_blocks', 'PRIMARY KEY' ) ), 'PK pk_hive_blocks not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_transactions', 'PRIMARY KEY' ) ), 'PK pk_hive_transactions not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_transactions_multisig', 'PRIMARY KEY' ) ), 'PK pk_hive_transactions_multisig not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_operations', 'PRIMARY KEY' ) ), 'PK pk_hive_operations not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_irreversible_data', 'PRIMARY KEY' ) ), 'PK pk_hive_irreversible_data not exists';
    ASSERT ( SELECT is_constraint_exists( 'pk_hive_applied_hardforks', 'PRIMARY KEY' ) ), 'PK pk_hive_applied_hardforks not exists';


    ASSERT EXISTS( SELECT 1 FROM pg_index pgi WHERE pgi.indrelid = 'hive.transactions'::regclass::oid ), 'No index for table hive.transactions';
    ASSERT EXISTS( SELECT 1 FROM pg_index pgi WHERE pgi.indrelid = 'hive.operations'::regclass::oid ), 'No index for table hive.operations';
END;
$BODY$
;
