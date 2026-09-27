-- issue #348: an application role must not be able to TRUNCATE (or add a foreign key or
-- trigger to) the tables every application shares. Row-level security does not cover
-- TRUNCATE, so without the revoke in authorization.sql alice could empty hafd.contexts and
-- unregister bob's application along with her own.

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CREATE SCHEMA ALICE;
    PERFORM hive.app_create_context( 'alice_context', 'alice' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CREATE SCHEMA BOB;
    PERFORM hive.app_create_context( 'bob_context', 'bob' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __table TEXT;
    __privilege TEXT;
BEGIN
    FOREACH __table IN ARRAY ARRAY[
          'hafd.contexts'
        , 'hafd.contexts_attachment'
        , 'hafd.registered_tables'
        , 'hafd.triggers'
        , 'hafd.state_providers_registered'
        , 'hafd.vacuum_requests'
        , 'hafd.applications'
        , 'hafd.application_dependencies'
    ] LOOP
        FOREACH __privilege IN ARRAY ARRAY[ 'TRUNCATE', 'REFERENCES', 'TRIGGER' ] LOOP
            ASSERT NOT has_table_privilege( current_user, __table, __privilege )
                , format( 'Alice has %s on %s', __privilege, __table );
        END LOOP;
    END LOOP;

    -- Catalog-driven as well, so a control table added to the GRANT ALL block later
    -- without a matching REVOKE is caught too, not only the eight listed above.
    FOR __table IN
        SELECT c.oid::regclass::text
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'hafd' AND c.relkind IN ( 'r', 'p' )
    LOOP
        FOREACH __privilege IN ARRAY ARRAY[ 'TRUNCATE', 'REFERENCES', 'TRIGGER' ] LOOP
            ASSERT NOT has_table_privilege( 'hive_applications_group', __table, __privilege )
                , format( 'hive_applications_group has %s on %s', __privilege, __table );
        END LOOP;
    END LOOP;

    -- The revoke is precise: what applications do use is still granted, so the test
    -- above cannot pass merely because alice lost her membership of the group.
    ASSERT has_table_privilege( current_user, 'hafd.contexts', 'INSERT' ), 'Alice lost INSERT on hafd.contexts';
    ASSERT has_table_privilege( current_user, 'hafd.contexts', 'DELETE' ), 'Alice lost DELETE on hafd.contexts';
    ASSERT has_table_privilege( current_user, 'hafd.contexts', 'UPDATE' ), 'Alice lost UPDATE on hafd.contexts';
    -- attach/detach update contexts_attachment, and app_api.sql takes a ROW SHARE lock on
    -- it, which needs UPDATE, DELETE or TRUNCATE -- so losing these would break the loop.
    ASSERT has_table_privilege( current_user, 'hafd.contexts_attachment', 'UPDATE' ), 'Alice lost UPDATE on hafd.contexts_attachment';
    ASSERT has_table_privilege( current_user, 'hafd.contexts_attachment', 'DELETE' ), 'Alice lost DELETE on hafd.contexts_attachment';
    ASSERT has_table_privilege( current_user, 'hafd.applications', 'INSERT' ), 'Alice lost INSERT on hafd.applications';

    -- And the statement itself is refused, not merely reported as unprivileged.
    -- Only insufficient_privilege is accepted: any other error propagates and fails.
    BEGIN
        TRUNCATE hafd.contexts CASCADE;
        ASSERT FALSE, 'Alice can TRUNCATE hafd.contexts';
    EXCEPTION WHEN insufficient_privilege THEN
    END;

    -- A precondition, not a detector: had the TRUNCATE succeeded, the ASSERT FALSE above
    -- would have rolled it back with its block and failed the test already. This shows
    -- there was another application's row for the TRUNCATE to destroy.
    ASSERT EXISTS( SELECT 1 FROM hafd.contexts WHERE name = 'bob_context' ), 'bob_context was never created';
END;
$BODY$
;
