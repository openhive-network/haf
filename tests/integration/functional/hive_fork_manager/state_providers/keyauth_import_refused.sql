CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __error_message TEXT;
BEGIN
    BEGIN
        PERFORM hive.app_state_provider_import( 'KEYAUTH', 'context' );
        ASSERT FALSE, 'Importing the removed KEYAUTH state provider did not raise an exception';
    EXCEPTION WHEN raise_exception THEN
        __error_message := SQLERRM;
    END;

    ASSERT __error_message LIKE '%KEYAUTH state provider was removed%' AND __error_message LIKE '%l2_framework%'
        , format( 'Unexpected error importing KEYAUTH: %s', __error_message );

    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
    PERFORM hive.app_state_provider_import( 'METADATA', 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT array_agg( state_provider::TEXT ORDER BY state_provider ) FROM hafd.state_providers_registered ) = ARRAY[ 'ACCOUNTS', 'METADATA' ]
        , 'Only ACCOUNTS and METADATA should be registered';

    ASSERT NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'hafd'
        AND table_name IN ( 'context_keyauth_a', 'context_keyauth_k', 'context_accountauth_a', 'context_authority_definition' )
    ), 'KEYAUTH tables were created';
END;
$BODY$
;
