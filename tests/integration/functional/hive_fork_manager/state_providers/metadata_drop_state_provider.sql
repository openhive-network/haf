
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
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

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_metadata' ), 'Metadata table was not dropped';
END;
$BODY$
;
