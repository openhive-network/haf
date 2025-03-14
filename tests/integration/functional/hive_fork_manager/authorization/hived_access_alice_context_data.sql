CREATE OR REPLACE PROCEDURE test_hived_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;
    PERFORM hive.end_massive_sync(5);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    DELETE FROM hafd.contexts WHERE name = 'alice_context';
    UPDATE hafd.contexts SET current_block_num = 100 WHERE name = 'alice_context';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- hived need to see context data to correctly tailore reversible blocks and events queue
    ASSERT EXISTS( SELECT * FROM hafd.contexts WHERE name='alice_context' ), 'Hived does not see Alice''s context';

    BEGIN
        CREATE TABLE hived_table(id INT ) INHERITS( alice.alice_context );
        ASSERT FALSE, 'Hived can register tabkle in Alice''s context';
    EXCEPTION WHEN OTHERS THEN
    END;

    --BEGIN
    --    DELETE FROM hafd.shadow_alice_alice_table;
    --    ASSERT FALSE, 'Hived can edit Alice''s shadow table';
    --EXCEPTION WHEN OTHERS THEN
    --END;

    ASSERT NOT EXISTS( SELECT * FROM hafd.state_providers_registered ), 'Hived sees Alices registered state provider';

    BEGIN
        PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'alice_context' );
        ASSERT FALSE, 'Hived can import state providers to Alices context';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_state_providers_update( 0, 100, 'alice_context' );
        ASSERT FALSE, 'Hived can update Alices state providers';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_state_providers_update( 0, 100, 'alice_context' );
        ASSERT FALSE, 'Hived can update Alices state providers';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_state_provider_drop( 'ACCOUNTS', 'alice_context' );
        ASSERT FALSE, 'Hived can drop Alices state providers';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA ALICE;

    PERFORM hive.app_create_context( 'alice_context', 'alice' );
    PERFORM hive.app_create_context( 'alice_context_detached', 'alice' );
    PERFORM hive.app_context_detach( 'alice_context_detached' );
    PERFORM hive.app_set_current_block_num( ARRAY[ 'alice_context_detached' ], 1 );
    CALL hive.appproc_context_attach( ARRAY[ 'alice_context_detached' ] );
    PERFORM hive.app_context_detach( ARRAY[ 'alice_context_detached' ] );

    CREATE TABLE alice.alice_table( id INT ) INHERITS( alice.alice_context );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'alice_context' );
    PERFORM hive.app_next_block( 'alice_context' );
    PERFORM hive.app_next_block( ARRAY[ 'alice_context' ] );
    INSERT INTO alice.alice_table VALUES( 10 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS( SELECT * FROM hafd.contexts WHERE name = 'alice_context' ), 'Alice''s context was removed by hived';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'alice_context' ) = 2, 'Alice''s context was updated by hived';
    ASSERT ( SELECT COUNT(*) FROM hafd.state_providers_registered ) = 1, 'Alice lost her state providers';
END;
$BODY$
;
