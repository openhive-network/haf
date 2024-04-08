
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
    ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.push_block(
            ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        );

    -- create non-forking context and its table
    PERFORM hive.app_create_context( _name => 'context', _is_forking := FALSE );
    CREATE SCHEMA A;
    CREATE TABLE A.table1( id INT) INHERITS( hive.context );

    -- move to irreversible block (1,1)
    PERFORM hive.app_next_block( 'context' );
    -- try to move to reversible block (2,2)m it is not forking so NULL will be returned
    PERFORM hive.app_next_block( 'context' );
    INSERT INTO A.table1( id ) VALUES (1);

    PERFORM hive.app_context_set_forking( 'context' ); -- back to block 1
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_context_set_non_forking( 'context' ); -- back to block 1
    INSERT INTO A.table1( id ) VALUES (10);
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
    ASSERT NOT EXISTS ( SELECT 1 FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' ), 'Column row_id still exists for forking context table';

    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context' AND is_attached = TRUE ), 'Attach flag is still set';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 1, 'Wrong current_block_num';
    ASSERT ( SELECT is_forking FROM hive.contexts WHERE name='context' ) = FALSE, 'context is is still marked as forking';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Trigger inserted something into shadow table1';

    SELECT * INTO __result FROM hive.app_next_block( 'context' );
    ASSERT __result IS NULL, 'Non forking context reach reversible block';

    -- 1 and 10 shall stay in a context's table
    ASSERT ( SELECT COUNT(*) FROM A.table1 ) = 2, 'Wrong number of rows in A.table1';
END;
$BODY$
;




