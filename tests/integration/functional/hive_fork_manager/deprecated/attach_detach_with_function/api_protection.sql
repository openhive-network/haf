CREATE OR REPLACE PROCEDURE test_hived_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.app_context_detach( 'alice_context' );
        ASSERT FALSE, 'Hived can call app_context_detach';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.app_context_detach( ARRAY[ 'alice_context' ] );
        ASSERT FALSE, 'Hived can call app_context_detach array';
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
    CREATE SCHEMA alice;

    PERFORM hive.app_create_context( 'alice_context', 'alice' );
    PERFORM hive.app_create_context( 'alice_context_detached', 'alice' );
    PERFORM hive.app_context_detach( 'alice_context_detached' );

    CREATE TABLE alice.alice_table( id INT ) INHERITS( alice.alice_context );
END;
$BODY$
;
