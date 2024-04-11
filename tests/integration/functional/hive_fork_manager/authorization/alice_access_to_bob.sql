CREATE OR REPLACE PROCEDURE test_hived_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;
    PERFORM hive.end_massive_sync(5);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice;

    PERFORM hive.app_create_context( 'alice_context' );
    PERFORM hive.app_create_context( 'alice_context_detached' );
    PERFORM hive.app_context_detach( 'alice_context_detached' );
    PERFORM hive.app_set_current_block_num( 'alice_context_detached', 1 );
    PERFORM hive.app_set_current_block_num( ARRAY[ 'alice_context_detached' ], 1 );
    PERFORM hive.app_get_current_block_num( 'alice_context_detached' );
    PERFORM hive.app_get_current_block_num( ARRAY[ 'alice_context_detached' ] );
    CREATE TABLE alice.alice_table( id INT ) INHERITS( hive.alice_context );
    PERFORM hive.app_next_block( 'alice_context' );
    PERFORM hive.app_next_block( ARRAY[ 'alice_context' ] );
    INSERT INTO alice.alice_table VALUES( 10 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'bob_context' );
    PERFORM hive.app_create_context( 'bob_context_detached' );
    PERFORM hive.app_context_detach( 'bob_context_detached' );
    PERFORM hive.app_set_current_block_num( 'bob_context_detached', 1 );
    PERFORM hive.app_set_current_block_num( ARRAY[ 'bob_context_detached' ], 1 );
    CREATE SCHEMA bob;
    CREATE TABLE bob.bob_table( id INT ) INHERITS( hive.bob_context );
    PERFORM hive.app_next_block( 'bob_context' );
    PERFORM hive.app_next_block( ARRAY[ 'bob_context' ] );
    INSERT INTO bob.bob_table VALUES( 100 );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'bob_context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_get_current_block_num( 'bob_context_detached' );
    PERFORM hive.app_get_current_block_num( 'bob_context' );

    PERFORM hive.app_get_current_block_num( ARRAY[ 'bob_context_detached' ] );
    PERFORM hive.app_get_current_block_num( ARRAY[ 'bob_context' ] );

    ASSERT EXISTS( SELECT * FROM hive.contexts WHERE name = 'bob_context' ), 'Alice does not see Bob context';
    ASSERT EXISTS( SELECT * FROM hive.contexts WHERE name = 'bob_context_detached' ), 'Alice does not see Bob context detached';
END
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_get_current_block_num( 'alice_context_detached' );
    PERFORM hive.app_get_current_block_num( 'alice_context' );

    PERFORM hive.app_get_current_block_num( ARRAY[ 'alice_context_detached' ] );
    PERFORM hive.app_get_current_block_num( ARRAY[ 'alice_context' ] );

    ASSERT EXISTS( SELECT * FROM hive.contexts WHERE name = 'alice_context' ), 'Bob does not see Alice context';
    ASSERT EXISTS( SELECT * FROM hive.contexts WHERE name = 'alice_context_detached' ), 'Bob does not see Alice context detached';
END;
$BODY$
;
