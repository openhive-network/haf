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
    PERFORM hive.app_create_context( 'alice_context' );
    PERFORM hive.app_create_context( 'alice_context_detached' );
    CALL hive.appproc_context_detach( 'alice_context_detached' );
    CREATE TABLE alice_table( id INT ) INHERITS( hive.alice_context );
END;
$BODY$
;
