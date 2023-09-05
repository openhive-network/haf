
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    PERFORM hive.context_set_irreversible_block( 'context', 100 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.context_set_irreversible_block( 'context', 50 );
    EXCEPTION WHEN OTHERS THEN
       RETURN;
    END;

    --ASSERT FALSE, "DID not catch expected exception";
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
     ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context' ) = 100;
END
$BODY$
;




