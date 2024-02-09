CREATE OR REPLACE PROCEDURE test_hived_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive.hived_connections( block_num, git_sha, time ) VALUES( 100000, '1234567890'::TEXT, now() - '50 hrs'::interval );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice' );

    UPDATE hive.contexts
    SET last_active_at = last_active_at - '5 hrs'::interval
    WHERE name = 'alice';

    PERFORM hive.app_create_context( 'alice_not_detached' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'bob' );

    UPDATE hive.contexts
    SET last_active_at = last_active_at - '5 hrs'::interval
    WHERE name = 'bob';
END
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- it pretends situation as sql-serializer works
    -- hived user is a member of hived_group, but do not inherits its SUPERUSER privilege
    -- when contexts are detached, then its views are switched, and only owner or SUPER user is able to do this
    -- hived is switching ROLE to its group, which has SUPERUSER privilege
    SET ROLE hived_group;
    CALL hive.proc_perform_dead_app_contexts_auto_detach();
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.app_context_is_attached( 'alice' ) = FALSE, 'alice is still attached';
    ASSERT hive.app_context_is_attached( 'bob' ) = FALSE, 'bob is still attached';
    ASSERT hive.app_context_is_attached( 'alice_not_detached' ) = TRUE, 'alice_not_detached is detached';
END
$BODY$
;