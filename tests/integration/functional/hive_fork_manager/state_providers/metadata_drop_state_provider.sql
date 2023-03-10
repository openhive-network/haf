DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
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
DECLARE
    __tables TEXT[];
BEGIN
    SELECT hive.start_provider_metadata( 'context' ) INTO __tables;

    ASSERT ( __tables = ARRAY[ 'context_metadata' ]::TEXT[] ), 'Wrong table name';

    PERFORM hive.drop_state_provider_metadata( 'context' );

END;
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
    ASSERT NOT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_metadata' ), 'Metadata table was not dropped';
END;
$BODY$
;
