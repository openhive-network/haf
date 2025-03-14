CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE TABLE table_with_constraints
    (
          a INTEGER NOT NULL
        , b INTEGER NOT NULL
        , c INTEGER NOT NULL
        , d BIGINT NOT NULL
        , e SMALLINT NOT NULL
        , CONSTRAINT table_with_constraints_1 PRIMARY KEY( a )
        , CONSTRAINT table_with_constraints_2 UNIQUE( b, c )
        , CONSTRAINT table_with_constraints_3 UNIQUE ( b, d )
    );

    CREATE INDEX IF NOT EXISTS table_with_constraints_4 ON table_with_constraints( e, b, c DESC ) INCLUDE( d, a );
    CREATE UNIQUE INDEX IF NOT EXISTS table_with_constraints_5 ON table_with_constraints( c ASC, d ASC );
    ALTER TABLE table_with_constraints ADD CONSTRAINT table_with_constraints_6 UNIQUE USING INDEX table_with_constraints_5;
    ALTER TABLE table_with_constraints ADD CONSTRAINT table_with_constraints_7 UNIQUE (e);

    CREATE TABLE IF NOT EXISTS indexes_constraints2 (
        table_name text,
        index_constraint_name text,
        command text,
        is_constraint boolean,
        is_index boolean,
        is_foreign_key boolean,
        status hafd.index_status
    );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM constraint_index_checker( TRUE );

    PERFORM hive.save_and_drop_indexes_constraints( 'public', 'table_with_constraints' );
    PERFORM constraint_index_checker( FALSE );

    INSERT INTO indexes_constraints2
    SELECT table_name, index_constraint_name, command, is_constraint, is_index, is_foreign_key, status -- include new column
    FROM hafd.indexes_constraints io
    ORDER BY io.index_constraint_name;

    PERFORM hive.restore_indexes( 'public.table_with_constraints' );
    PERFORM constraint_index_checker( TRUE );

    PERFORM hive.save_and_drop_indexes_constraints( 'public', 'table_with_constraints' );
    PERFORM constraint_index_checker( FALSE );
END;
$BODY$
;

DROP FUNCTION IF EXISTS is_constraint_exists;
CREATE FUNCTION is_constraint_exists( _schema TEXT, _table_name TEXT, _constraint_name TEXT )
    RETURNS bool
    LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
__result bool;
BEGIN
SELECT EXISTS (
		SELECT 1
		FROM pg_constraint pgc
			JOIN pg_namespace nsp on nsp.oid = pgc.connamespace
			JOIN information_schema.table_constraints tc ON pgc.conname = tc.constraint_name AND nsp.nspname = tc.constraint_schema
		WHERE tc.constraint_type != 'FOREIGN KEY' AND tc.table_schema = _schema AND tc.table_name = _table_name AND pgc.conname = _constraint_name
           ) INTO __result;
RETURN __result;
END;
$BODY$
;

DROP FUNCTION IF EXISTS is_index_exists;
CREATE FUNCTION is_index_exists( _schema TEXT, _table_name TEXT, _index_name TEXT )
    RETURNS bool
    LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
__result bool;
BEGIN
SELECT EXISTS (
		SELECT 1
		  FROM pg_indexes
		  WHERE schemaname = _schema AND tablename = _table_name AND indexname = _index_name
           ) INTO __result;
RETURN __result;
END;
$BODY$
;

DROP FUNCTION IF EXISTS constraint_index_checker;
CREATE FUNCTION constraint_index_checker( _expected_value BOOL )
        RETURNS void
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
	ASSERT ( SELECT is_constraint_exists( 'public', 'table_with_constraints', 'table_with_constraints_1' ) = _expected_value ) , 'Problem with table_with_constraints_1';
	ASSERT ( SELECT is_constraint_exists( 'public', 'table_with_constraints', 'table_with_constraints_2' ) = _expected_value ) , 'Problem with table_with_constraints_2';
	ASSERT ( SELECT is_constraint_exists( 'public', 'table_with_constraints', 'table_with_constraints_3' ) = _expected_value ) , 'Problem with table_with_constraints_3';
	ASSERT ( SELECT is_constraint_exists( 'public', 'table_with_constraints', 'table_with_constraints_6' ) = _expected_value ) , 'Problem with table_with_constraints_6';
	ASSERT ( SELECT is_constraint_exists( 'public', 'table_with_constraints', 'table_with_constraints_7' ) = _expected_value ) , 'Problem with table_with_constraints_7';
	ASSERT ( SELECT is_index_exists( 'public', 'table_with_constraints', 'table_with_constraints_4' ) = _expected_value ) , 'Problem with table_with_constraints_4';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS (
        (SELECT table_name, index_constraint_name, command, status, is_constraint, is_index, is_foreign_key
          FROM indexes_constraints2 ORDER BY index_constraint_name)
        EXCEPT
        SELECT table_name, index_constraint_name, command, status, is_constraint, is_index, is_foreign_key
          FROM hafd.indexes_constraints ORDER BY index_constraint_name
    ) , 'Saving indexes and constraints failed';
END;
$BODY$
;
