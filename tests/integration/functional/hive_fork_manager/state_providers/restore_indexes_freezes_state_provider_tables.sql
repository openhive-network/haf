CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( 'context', _schema => 'a', _is_forking => FALSE );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
    PERFORM hive.app_state_provider_import( 'METADATA', 'context' );
    DELETE FROM hafd.vacuum_requests;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_restore_indexes( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (
        SELECT array_agg( format( '%s.%s:%s:%s', schema_name, table_name, kind, status ) ORDER BY table_name )
        FROM hafd.vacuum_requests
    ) = ARRAY[
          'hafd.context_accounts:freeze:requested'
        , 'hafd.context_metadata:freeze:requested'
    ], 'app_restore_indexes(context) should request a freeze vacuum of every state-provider table of the context';
END;
$BODY$
;
