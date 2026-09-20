-- Editing the columns of a registered table recreates its shadow table from the
-- origin table's layout (CREATE TABLE ... AS TABLE ... WITH NO DATA). Check that this
-- works when the origin table is populated: the new shadow table has the new column,
-- is empty, and records changes.
CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE A.table1( id INTEGER NOT NULL, smth INTEGER ) INHERITS( a.context );
    PERFORM hive.context_next_block( 'context' ); -- 1
    INSERT INTO a.table1( id, smth ) SELECT g, g FROM generate_series( 1, 50000 ) g;
    PERFORM hive.context_set_irreversible_block( 'context', 1 ); -- shadow table must be empty to edit the table
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ALTER TABLE a.table1 ADD COLUMN test_column INTEGER;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM a.table1 ) = 50000, 'Origin table lost rows';
    ASSERT EXISTS(
        SELECT * FROM information_schema.columns iss WHERE iss.table_schema='hafd' AND iss.table_name='shadow_a_table1' AND iss.column_name='test_column'
        )
        , 'Shadow table was not recreated with the new column'
    ;
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 0, 'Recreated shadow table is not empty';
    ASSERT pg_relation_size( 'hafd.shadow_a_table1' ) = 0, 'Recreated shadow table is not an empty file';

    -- and it still records changes
    PERFORM hive.context_next_block( 'context' ); -- 2
    UPDATE a.table1 SET test_column = 1 WHERE id = 1;
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 1, 'Recreated shadow table does not record changes';
END;
$BODY$
;
