DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hive.fork VALUES( 2, 2, '2016-06-22 19:10:24-07'::timestamp );
    INSERT INTO hive.fork VALUES( 3, 3, '2016-06-22 19:10:25-07'::timestamp );

    PERFORM hive.app_create_context( 'context_a' );
    PERFORM hive.app_create_context( 'context_b' );
    PERFORM hive.app_create_context( 'context_c' );

    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context_a );
    CREATE SCHEMA B;
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( hive.context_b );
    CREATE SCHEMA C;
    CREATE TABLE C.table1(id  INTEGER ) INHERITS( hive.context_c );

    PERFORM hive.app_context_detach( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
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
BEGIN
    PERFORM hive.app_context_attach( ARRAY[ 'context_a', 'context_b', 'context_c' ] , 2 );
    INSERT INTO A.table1( id ) VALUES (10);
    INSERT INTO B.table1( id ) VALUES (10);
    INSERT INTO C.table1( id ) VALUES (10);
END;
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
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context_a' AND is_attached = TRUE ), 'Attach flag is still not set A';
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context_a' AND fork_id = 2 ), 'Wrong fork_id A';
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context_b' AND is_attached = TRUE ), 'Attach flag is still not set B';
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context_b' AND fork_id = 2 ), 'Wrong fork_id B';
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context_c' AND is_attached = TRUE ), 'Attach flag is still not set C';
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context_c' AND fork_id = 2 ), 'Wrong fork_id C';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 1, 'Trigger inserted something into shadow A.table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_b_table1 ) = 1, 'Trigger inserted something into shadow B.table1';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_c_table1 ) = 1, 'Trigger inserted something into shadow C.table1';
END;
$BODY$
;


