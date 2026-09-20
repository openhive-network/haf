-- A shadow table that once held many rows keeps its file size after they are
-- removed (VACUUM only truncates an empty tail), and hive.remove_obsolete_operations
-- scans that whole file on every block. Once such a table is empty it must be
-- truncated; while it still holds rows of reversible blocks it must be left alone.
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context', 'a' );
    CREATE TABLE table_emptied( id INTEGER NOT NULL ) INHERITS( a.context );
    CREATE TABLE table_still_used( id INTEGER NOT NULL ) INHERITS( a.context );
    CREATE TABLE table_small( id INTEGER NOT NULL ) INHERITS( a.context );

    PERFORM hive.context_next_block( 'context' ); -- 1: bulk writes, well above the shrink threshold
    INSERT INTO table_emptied( id ) SELECT generate_series( 1, 100000 );
    INSERT INTO table_still_used( id ) SELECT generate_series( 1, 100000 );
    INSERT INTO table_small( id ) VALUES( 1 );

    PERFORM hive.context_next_block( 'context' ); -- 2
    PERFORM hive.context_next_block( 'context' ); -- 3: still reversible after the WHEN step
    INSERT INTO table_still_used( id ) VALUES( 100001 );

    ASSERT pg_relation_size( 'hafd.shadow_public_table_emptied' ) > 1024 * 1024, 'Test setup: shadow table is not big enough';
    ASSERT pg_relation_size( 'hafd.shadow_public_table_still_used' ) > 1024 * 1024, 'Test setup: shadow table is not big enough';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_set_irreversible_block( 'context', 2 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __operation_id BIGINT;
BEGIN
    -- emptied and oversized: the file is given back
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table_emptied ) = 0, 'Obsolete rows were not removed';
    ASSERT pg_relation_size( 'hafd.shadow_public_table_emptied' ) = 0, 'An empty, oversized shadow table was not truncated';

    -- oversized but still holding a reversible row: untouched, the row survives
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table_still_used ) = 1, 'Rows of reversible blocks must stay';
    ASSERT EXISTS ( SELECT FROM hafd.shadow_public_table_still_used hs WHERE hs.id = 100001 AND hs.hive_block_num = 3 ), 'No expected row';
    ASSERT pg_relation_size( 'hafd.shadow_public_table_still_used' ) > 1024 * 1024, 'A shadow table with reversible rows must not be truncated';

    -- small table: nothing to do
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_public_table_small ) = 0, 'Obsolete rows were not removed from the small table';

    -- the truncated shadow table keeps working, and its operation ids keep growing
    PERFORM hive.context_next_block( 'context' ); -- 4
    INSERT INTO table_emptied( id ) VALUES( 100001 );
    SELECT hs.hive_operation_id INTO __operation_id FROM hafd.shadow_public_table_emptied hs WHERE hs.id = 100001 AND hs.hive_block_num = 4;
    ASSERT __operation_id > 100000, 'hive_operation_id sequence was restarted by the truncate';

    PERFORM hive.context_back_from_fork( 'context', 3 );
    ASSERT NOT EXISTS ( SELECT FROM table_emptied WHERE id = 100001 ), 'Back from fork does not work after the shadow table was truncated';
    ASSERT ( SELECT COUNT(*) FROM table_emptied ) = 100000, 'Back from fork reverted too much';
END
$BODY$
;
