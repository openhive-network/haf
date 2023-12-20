CREATE OR REPLACE PROCEDURE test_hived_test_given()
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
    VALUES (5, 'initminer', 1);
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );

    UPDATE hive.contexts SET detached_block_num = 5;

    PERFORM hive.context_next_block( 'context' ); -- move to block 1
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL hive.appproc_context_detach( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context' AND is_attached = FALSE ), 'Attach flag is still set';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 0, 'Wrong current_block_num';
    ASSERT ( SELECT detached_block_num FROM hive.contexts WHERE name='context' ) IS NULL, 'detached_block_num was not set to NULL';
END;
$BODY$
;




