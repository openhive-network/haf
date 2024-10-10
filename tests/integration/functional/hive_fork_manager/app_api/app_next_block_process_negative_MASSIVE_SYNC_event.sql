
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive_data.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    PERFORM hive.app_create_context( 'context_non_forking', 'a' );

    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- NOTHING TO DO HERE
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'Some block range is returned for inconsistence data - forking';

    SELECT * FROM hive.app_next_block( 'context_non_forking' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'Some block range is returned for inconsistence data - non forking';
END
$BODY$
;




