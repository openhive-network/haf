CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.push_block(
            ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA bob;
    PERFORM hive.app_create_context( 'bob_context', 'bob' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice_context', 'alice' );
    CREATE TABLE alice.alice_table( id INT ) INHERITS( alice.alice_context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        TRUNCATE hafd.contexts CASCADE;
        ASSERT FALSE, 'Alice can truncate hafd.contexts';
    EXCEPTION WHEN insufficient_privilege THEN
    END;

    PERFORM hive.app_context_detach( 'alice_context' );
    PERFORM hive.app_context_attach( 'alice_context' );
    PERFORM hive.app_next_block( 'alice_context' );
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
          'hafd.contexts', 'hafd.contexts_attachment', 'hafd.registered_tables', 'hafd.triggers'
        , 'hafd.state_providers_registered', 'hafd.vacuum_requests', 'hafd.applications', 'hafd.application_dependencies' ]
    LOOP
        FOREACH __privilege IN ARRAY ARRAY[ 'TRUNCATE', 'REFERENCES', 'TRIGGER' ]
        LOOP
            ASSERT NOT has_table_privilege( 'alice', __table, __privilege ), format( 'Alice has %s on %s', __privilege, __table );
        END LOOP;
    END LOOP;

    ASSERT EXISTS( SELECT 1 FROM hafd.contexts WHERE name = 'bob_context' ), 'bob_context was removed';
    ASSERT ( SELECT is_attached FROM hafd.contexts_attachment ca JOIN hafd.contexts c ON c.id = ca.context_id WHERE c.name = 'alice_context' ), 'alice_context is not attached';
    ASSERT EXISTS( SELECT 1 FROM hafd.registered_tables WHERE origin_table_schema = 'alice' AND origin_table_name = 'alice_table' ), 'alice_table is not registered';

    PERFORM hive.app_remove_context( 'alice_context' );
    ASSERT NOT EXISTS( SELECT 1 FROM hafd.contexts WHERE name = 'alice_context' ), 'alice_context was not removed';
END;
$BODY$
;
