
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    CREATE SCHEMA B;
    PERFORM hive.app_create_context( 'context_b', 'b' );
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( b.context_b );

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); -- move to block 1
    PERFORM hive.app_context_set_non_forking( ARRAY[ 'context', 'context_b' ] ); -- back to block 0
    INSERT INTO A.table1( id ) VALUES (10);
    INSERT INTO B.table1( id ) VALUES (20);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
        __result hive.blocks_range;
BEGIN
    ASSERT EXISTS ( SELECT * FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context' AND hca.is_attached = TRUE ), 'Attach flag is still set';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 0, 'Wrong current_block_num';
    ASSERT ( SELECT is_forking FROM hive.contexts WHERE name='context' ) = FALSE, 'context is is still marked as forking';

    ASSERT EXISTS ( SELECT * FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context_b' AND hca.is_attached = TRUE ), 'b) Attach flag is still set';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context_b' ) = 0, 'b) Wrong current_block_num';
    ASSERT ( SELECT is_forking FROM hive.contexts WHERE name='context_b' ) = FALSE, 'b) context is is still marked as forking';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Trigger inserted something into shadow table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_b_table1 ) = 0, 'Trigger inserted something into shadow b table1';

    SELECT * INTO __result FROM hive.app_next_block( ARRAY[ 'context', 'context_b' ] );

    ASSERT NOT EXISTS (SELECT 0 FROM pg_class where relname = 'idx_a_table1_row_id' ), 'Index for table a.table1 rowid still exists';
    ASSERT NOT EXISTS (SELECT 0 FROM pg_class where relname = 'idx_b_table1_row_id' ), 'Index for table b.table1 rowid still exists';

    ASSERT __result IS NULL, 'Non forking context reach reversible block';
END;
$BODY$
;




