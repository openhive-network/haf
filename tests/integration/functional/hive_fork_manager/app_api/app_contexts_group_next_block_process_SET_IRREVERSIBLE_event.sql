
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
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

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );


    CREATE SCHEMA A;
    CREATE SCHEMA B;

    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    PERFORM hive.app_create_context( 'context_b', _schema => 'b'  );
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( b.context_b );

    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); -- NEW_BLOCK event block 1
    INSERT INTO A.table1(id) VALUES( 1 );
    INSERT INTO B.table1(id) VALUES( 1 );
    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); -- NEW_BLOCK event block 2
    INSERT INTO A.table1(id) VALUES( 2 );
    INSERT INTO B.table1(id) VALUES( 2 );
    PERFORM hive.app_next_block( ARRAY[ 'context', 'context_b' ] ); -- NEW_BLOCK event block 3
    INSERT INTO A.table1(id) VALUES( 3 );
    INSERT INTO B.table1(id) VALUES( 3 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __result INT;
BEGIN
    PERFORM hive.set_irreversible( 3 );
    SELECT hive.app_next_block( ARRAY[ 'context', 'context_b' ] ) INTO __result;
    ASSERT __result IS NULL, 'Processing  SET_IRREVERSIBLE event did not return NULL';
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context' ) = 3, 'Wrong current block num';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context_b' ) = 3, 'Wrong current block num b';
    ASSERT ( SELECT events_id FROM hafd.contexts WHERE name='context' ) = 4, 'Wrong events id';
    ASSERT ( SELECT events_id FROM hafd.contexts WHERE name='context_b' ) = 4, 'Wrong events id b';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name='context' ) = 3, 'Wrong irreversible';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name='context_b' ) = 3, 'Wrong irreversible b';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 3, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 3 ), 'No id 3';

    ASSERT ( SELECT COUNT(*)  FROM B.table1 ) = 3, 'Wrong number of rows in app table b';
    ASSERT EXISTS ( SELECT *  FROM B.table1 WHERE id = 1 ), 'No id 1 b';
    ASSERT EXISTS ( SELECT *  FROM B.table1 WHERE id = 2 ), 'No id 2 b';
    ASSERT EXISTS ( SELECT *  FROM B.table1 WHERE id = 3 ), 'No id 3 b';

    ASSERT NOT EXISTS ( SELECT * FROM hafd.shadow_a_table1 ), 'Shadow table is not empty';
    ASSERT NOT EXISTS ( SELECT * FROM hafd.shadow_b_table1 ), 'Shadow table is not empty b';
END
$BODY$
;




