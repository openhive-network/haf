-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE test_hived_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);
    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
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

    PERFORM hive.app_create_context( 'alice_context', 'alice' );
    PERFORM hive.app_create_context( 'alice_context_detached', 'alice' );
    PERFORM hive.app_context_detach( 'alice_context_detached' );
    PERFORM hive.app_set_current_block_num( 'alice_context_detached', 1 );
    PERFORM hive.app_set_current_block_num( ARRAY[ 'alice_context_detached' ], 1 );
    PERFORM hive.app_get_current_block_num( 'alice_context_detached' );
    PERFORM hive.app_get_current_block_num( ARRAY[ 'alice_context_detached' ] );
    CREATE TABLE alice.alice_table( id INT ) INHERITS( alice.alice_context );
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
    CREATE SCHEMA BOB;

    PERFORM hive.app_create_context( 'bob_context', 'bob' );
    PERFORM hive.app_create_context( 'bob_context_detached', 'bob' );
    PERFORM hive.app_context_detach( 'bob_context_detached' );
    PERFORM hive.app_set_current_block_num( 'bob_context_detached', 1 );
    PERFORM hive.app_set_current_block_num( ARRAY[ 'bob_context_detached' ], 1 );

    CREATE TABLE bob.bob_table( id INT ) INHERITS( bob.bob_context );
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

    ASSERT EXISTS( SELECT * FROM hafd.contexts WHERE name = 'bob_context' ), 'Alice does not see Bob context';
    ASSERT EXISTS( SELECT * FROM hafd.contexts WHERE name = 'bob_context_detached' ), 'Alice does not see Bob context detached';
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

    ASSERT EXISTS( SELECT * FROM hafd.contexts WHERE name = 'alice_context' ), 'Bob does not see Alice context';
    ASSERT EXISTS( SELECT * FROM hafd.contexts WHERE name = 'alice_context_detached' ), 'Bob does not see Alice context detached';
END;
$BODY$
;
