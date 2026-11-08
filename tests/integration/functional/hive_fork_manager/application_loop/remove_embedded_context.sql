-- Application registry (issue #347): removing a context that is part of another
-- application (the balance tracker's context inside haf_block_explorer) changes or
-- unregisters that application. It is refused for a role that cannot impersonate
-- the application's owner, as hive.app_register is, and allowed to the owner and to
-- haf_admin; hive.app_context_owner names the application a context belongs to.
-- alice plays the embedded application, alice_impersonal the embedding one.

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA embedded;
    PERFORM hive.app_create_context( _name => 'embedded_ctx', _schema => 'embedded', _is_forking => FALSE );
    PERFORM hive.app_create_context( _name => 'embedded2_ctx', _schema => 'embedded', _is_forking => FALSE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA host;
    PERFORM hive.app_create_context( _name => 'host_ctx', _schema => 'host', _is_forking => FALSE );
    PERFORM hive.app_create_context( _name => 'host2_ctx', _schema => 'host', _is_forking => FALSE );
    PERFORM hive.app_register( 'host_app', ARRAY[ 'host_ctx', 'embedded_ctx' ] );
    PERFORM hive.app_register( 'host2_app', ARRAY[ 'host2_ctx', 'embedded2_ctx' ] );
    PERFORM hive.app_add_dependency( 'host2_app', 'host_app' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __error TEXT;
BEGIN
    ASSERT hive.app_context_owner( 'embedded_ctx' ) = 'host_app', 'app_context_owner does not name the embedding application';
    ASSERT hive.app_context_owner( 'no_such_ctx' ) IS NULL, 'app_context_owner names an application for a missing context';

    BEGIN
        PERFORM hive.app_remove_context( 'embedded_ctx' );
    EXCEPTION WHEN raise_exception THEN
        __error := SQLERRM;
    END;
    ASSERT __error LIKE 'Cannot remove context embedded_ctx: it belongs to application host_app owned by alice_impersonal%', 'removal from a foreign application was not refused: ' || COALESCE( __error, 'no error' );
    ASSERT hive.app_context_exists( 'embedded_ctx' ), 'refused removal removed the context';
    ASSERT ( SELECT contexts FROM hafd.applications WHERE name = 'host_app' ) = ARRAY[ 'host_ctx', 'embedded_ctx' ], 'refused removal changed the registration';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- the embedding application tears itself down together with what it embeds
    PERFORM hive.app_remove_context( 'embedded_ctx' );
    ASSERT ( SELECT contexts FROM hafd.applications WHERE name = 'host_app' ) = ARRAY[ 'host_ctx' ], 'removed context is still registered';
    ASSERT hive.app_context_owner( 'embedded_ctx' ) IS NULL, 'removed context still has an application';

    PERFORM hive.app_remove_context( 'host_ctx' );
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = 'host_app' ), 'application without contexts is still registered';
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.application_dependencies WHERE depends_on = 'host_app' ), 'dependency on the unregistered application remains';
    ASSERT EXISTS ( SELECT 1 FROM hafd.applications WHERE name = 'host2_app' ), 'dependent application got unregistered';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- the embedded application's uninstall script, connected as haf_admin
    PERFORM hive.app_remove_context( 'embedded2_ctx' );
    ASSERT ( SELECT contexts FROM hafd.applications WHERE name = 'host2_app' ) = ARRAY[ 'host2_ctx' ], 'haf_admin removal did not update the registration';
    ASSERT hive.app_context_owner( 'host2_ctx' ) = 'host2_app', 'app_context_owner lost the remaining context';
    ASSERT hive.app_context_owner( 'embedded2_ctx' ) IS NULL, 'removed context still has an application';
END;
$BODY$
;
