DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    PERFORM hive.context_set_irreversible_block( 'context', 100 );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
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

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
     ASSERT ( SELECT irreversible_block FROM hive.contexts WHERE name = 'context' ) = 100;
END
$BODY$
;




