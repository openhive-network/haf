DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
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

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.back_from_fork( 2 );

    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    PERFORM hive.app_next_block( 'context' ); -- (1,1) END_MASSIVE_SYNC e1
    INSERT INTO A.table1(id) VALUES( 1 );
    PERFORM hive.app_next_block( 'context' ); -- (2,2) NEW_BLOCK event block 2 e2
    INSERT INTO A.table1(id) VALUES( 2 );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __result INT;
BEGIN
    -- theoretically next_block should process NEW_BLOCK 3, but optimizations for fork
    -- will ommit unnecessary events which will be rewinded, and we get BFF EVENT 2
    SELECT hive.app_next_block( 'context' ) INTO __result;
    ASSERT __result IS NULL, 'Processing  BFF event did not return NULL';
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 2, 'Wrong current block num';
    ASSERT ( SELECT events_id FROM hive.contexts WHERE name='context' ) = 4, 'Wrong events id';

    ASSERT ( SELECT COUNT(*)  FROM A.table1 ) = 2, 'Wrong number of rows in app table';
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 1 ), 'No id 1' ;
    ASSERT EXISTS ( SELECT *  FROM A.table1 WHERE id = 2 ), 'No id 2' ;
END
$BODY$
;




