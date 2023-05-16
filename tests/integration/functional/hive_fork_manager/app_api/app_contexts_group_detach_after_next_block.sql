DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context_a' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context_a );

    PERFORM hive.app_create_context( 'context_b' );
    CREATE SCHEMA B;
    CREATE TABLE B.table1(id  INTEGER ) INHERITS( hive.context_b );

    PERFORM hive.app_create_context( 'context_c' );
    CREATE SCHEMA C;
    CREATE TABLE C.table1(id  INTEGER ) INHERITS( hive.context_c );

    INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1);

    PERFORM hive.set_irreversible( 5 );

    PERFORM hive.app_next_block( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
    PERFORM hive.app_next_block( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
    PERFORM hive.app_next_block( ARRAY[ 'context_a', 'context_b', 'context_c' ] );

    INSERT INTO  A.table1( id ) VALUES ( 66 ),( 67);
    INSERT INTO  A.table1( id ) VALUES ( 300 ),( 301);

    INSERT INTO  B.table1( id ) VALUES ( 66 ),( 67);
    INSERT INTO  B.table1( id ) VALUES ( 300 ),( 301);

    INSERT INTO  C.table1( id ) VALUES ( 66 ),( 67);
    INSERT INTO  C.table1( id ) VALUES ( 300 ),( 301);

    ASSERT ( SELECT count(*) FROM hive.shadow_a_table1 ) = 4, 'shadow table has to be filled a';
    ASSERT ( SELECT count(*) FROM hive.shadow_b_table1 ) = 4, 'shadow table has to be filled b';
    ASSERT ( SELECT count(*) FROM hive.shadow_c_table1 ) = 4, 'shadow table has to be filled c';

    PERFORM hive.app_context_detach( ARRAY[ 'context_a', 'context_b', 'context_c' ] );
END;
$BODY$
;




