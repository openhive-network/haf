
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hafd.fork VALUES( 2, 2, '2016-06-22 19:10:24-07'::timestamp );
    INSERT INTO hafd.fork VALUES( 3, 3, '2016-06-22 19:10:25-07'::timestamp );

    CREATE SCHEMA A;
    CREATE SCHEMA B;
    CREATE SCHEMA C;

    PERFORM hive.app_create_context( 'context_a', 'a' );
    PERFORM hive.app_create_context( 'context_b', 'b' );
    PERFORM hive.app_create_context( 'context_c', 'c' );

    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context_a );
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( b.context_b );
    CREATE TABLE C.table1(id  INTEGER ) INHERITS( c.context_c );

    PERFORM hive.app_context_detach( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( ARRAY[ 'context_a', 'context_b', 'context_c' ] , 2 );
    PERFORM hive.app_context_attach( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
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
    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context_a' AND hca.is_attached = TRUE ), 'Attach flag is still not set A';
    ASSERT EXISTS ( SELECT * FROM hafd.contexts WHERE name='context_a' AND fork_id = 2 ), 'Wrong fork_id A';
    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context_b' AND hca.is_attached = TRUE ), 'Attach flag is still not set B';
    ASSERT EXISTS ( SELECT * FROM hafd.contexts WHERE name='context_b' AND fork_id = 2 ), 'Wrong fork_id B';
    ASSERT EXISTS ( SELECT * FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hca.context_id=hc.id WHERE hc.name='context_c' AND hca.is_attached = TRUE ), 'Attach flag is still not set C';
    ASSERT EXISTS ( SELECT * FROM hafd.contexts WHERE name='context_c' AND fork_id = 2 ), 'Wrong fork_id C';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_table1 ) = 1, 'Trigger inserted something into shadow A.table1';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_b_table1 ) = 1, 'Trigger inserted something into shadow B.table1';
    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_c_table1 ) = 1, 'Trigger inserted something into shadow C.table1';
END;
$BODY$
;


