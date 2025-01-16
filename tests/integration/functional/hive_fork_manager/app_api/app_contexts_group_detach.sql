
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    CREATE SCHEMA A;
    CREATE SCHEMA B;
    CREATE SCHEMA C;

    PERFORM hive.app_create_context( 'context_a', 'a' );
    PERFORM hive.app_create_context( 'context_b', 'b' );
    PERFORM hive.app_create_context( 'context_c', 'c' );

    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context_a );

    CREATE TABLE B.table1(id  INTEGER ) INHERITS( b.context_b );

    CREATE TABLE C.table1(id  INTEGER ) INHERITS( c.context_c );

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_next_block( ARRAY [ 'context_a', 'context_b', 'context_c' ] ); -- move to block 1
    PERFORM hive.app_context_detach( ARRAY [ 'context_a', 'context_b', 'context_c' ] ); -- back to block 0
    INSERT INTO A.table1( id ) VALUES (10);
    INSERT INTO B.table1( id ) VALUES (10);
    INSERT INTO C.table1( id ) VALUES (10);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context_a' AND hca.is_attached = FALSE ), 'Attach flag is still set context_a';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context_a' ) = 0, 'Wrong current_block_num context_a';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 0, 'Trigger inserted something into shadow table1 context_a';

    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context_b' AND hca.is_attached = FALSE ), 'Attach flag is still set context_b';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context_b' ) = 0, 'Wrong current_block_num context_b';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_b_table1 ) = 0, 'Trigger inserted something into shadow table1 context_b';

    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context_c' AND hca.is_attached = FALSE ), 'Attach flag is still set context_c';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context_c' ) = 0, 'Wrong current_block_num context_c';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_c_table1 ) = 0, 'Trigger inserted something into shadow table1 context_c';
END;
$BODY$
;




