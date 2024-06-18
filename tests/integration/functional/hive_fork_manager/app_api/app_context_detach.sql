
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

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.context_next_block( 'context' ); -- move to block 1
    PERFORM hive.app_context_detach( 'context' ); -- back to block 0
    INSERT INTO A.table1( id ) VALUES (10);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context' AND hca.is_attached = FALSE ), 'Attach flag is still set';
    ASSERT ( SELECT current_block_num FROM hive.contexts WHERE name='context' ) = 0, 'Wrong current_block_num';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 0, 'Trigger inserted something into shadow table1';
END;
$BODY$
;




