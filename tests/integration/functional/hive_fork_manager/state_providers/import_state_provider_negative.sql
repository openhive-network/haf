
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
        BEGIN
        PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'not-existed-context' );
            ASSERT FALSE, 'Cannot raise expected exception when context does not exists';
        EXCEPTION WHEN OTHERS THEN
        END;


        PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.state_providers_registered WHERE context_id = 1 AND state_provider = 'ACCOUNTS' AND tables = ARRAY[ 'context_accounts' ]::TEXT[] ) = 1, 'State provider not registered';
END;
$BODY$
;




