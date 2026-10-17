CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA admin_app;
    PERFORM hive.app_create_context( _name => 'admin_ctx', _schema => 'admin_app' );
    CREATE TABLE admin_app.t1( id INTEGER, val TEXT ) INHERITS( admin_app.admin_ctx );
    CREATE INDEX admin_t1_val_idx ON admin_app.t1( val );
    PERFORM hive.app_register_index_dependency( 'admin_ctx', 'CREATE INDEX admin_t1_val_idx ON admin_app.t1( val )' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice_app;
    PERFORM hive.app_create_context( _name => 'alice_ctx', _schema => 'alice_app' );
    CREATE TABLE alice_app.t1( id INTEGER, val TEXT ) INHERITS( alice_app.alice_ctx );
    CREATE INDEX alice_t1_own_idx ON alice_app.t1( id );
    CREATE INDEX alice_t1_shared_idx ON alice_app.t1( val );
    PERFORM hive.app_register_index_dependency( 'alice_ctx', 'CREATE INDEX alice_t1_own_idx ON alice_app.t1( id )' );
    PERFORM hive.app_register_index_dependency( 'alice_ctx', 'CREATE INDEX alice_t1_shared_idx ON alice_app.t1( val )' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __snapshot TEXT;
BEGIN
    CREATE SCHEMA bob_app;
    PERFORM hive.app_create_context( _name => 'bob_ctx', _schema => 'bob_app' );
    PERFORM hive.app_register_index_dependency( 'bob_ctx', 'CREATE INDEX alice_t1_shared_idx ON alice_app.t1( val )' );

    SELECT string_agg( format( '%s:%s:%s', table_name, index_constraint_name, contexts ), ',' ORDER BY table_name, index_constraint_name )
    INTO __snapshot
    FROM hafd.indexes_constraints;

    BEGIN
        PERFORM hive.app_remove_index_dependencies( 'alice_ctx' );
        ASSERT FALSE, 'Bob removed index dependencies of Alice''s context';
    EXCEPTION WHEN insufficient_privilege THEN
    END;

    ASSERT (
        SELECT string_agg( format( '%s:%s:%s', table_name, index_constraint_name, contexts ), ',' ORDER BY table_name, index_constraint_name )
        FROM hafd.indexes_constraints
    ) = __snapshot, 'Failed removal by a non-owner changed hafd.indexes_constraints';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_remove_context( 'admin_ctx' );
END;
$BODY$
;

-- alice_impersonal is a member of alice (the context owner), not its owner itself
CREATE OR REPLACE PROCEDURE alice_impersonal_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_remove_context( 'alice_ctx' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __bob_ctx_id INT;
BEGIN
    ASSERT NOT EXISTS ( SELECT FROM hafd.contexts WHERE name IN ( 'admin_ctx', 'alice_ctx' ) ), 'Contexts were not removed';

    ASSERT NOT EXISTS ( SELECT FROM pg_indexes WHERE schemaname = 'admin_app' AND indexname = 'admin_t1_val_idx' )
        , 'admin_t1_val_idx was not dropped';
    ASSERT NOT EXISTS ( SELECT FROM hafd.indexes_constraints WHERE index_constraint_name = 'admin_t1_val_idx' )
        , 'admin_t1_val_idx dependency was not removed';

    ASSERT NOT EXISTS ( SELECT FROM pg_indexes WHERE schemaname = 'alice_app' AND indexname = 'alice_t1_own_idx' )
        , 'alice_t1_own_idx was not dropped';
    ASSERT NOT EXISTS ( SELECT FROM hafd.indexes_constraints WHERE index_constraint_name = 'alice_t1_own_idx' )
        , 'alice_t1_own_idx dependency was not removed';

    SELECT id INTO __bob_ctx_id FROM hafd.contexts WHERE name = 'bob_ctx';
    ASSERT EXISTS ( SELECT FROM pg_indexes WHERE schemaname = 'alice_app' AND indexname = 'alice_t1_shared_idx' )
        , 'alice_t1_shared_idx was dropped although bob_ctx depends on it';
    ASSERT ( SELECT contexts FROM hafd.indexes_constraints WHERE index_constraint_name = 'alice_t1_shared_idx' ) = ARRAY[ __bob_ctx_id ]
        , 'alice_t1_shared_idx should remain registered only for bob_ctx';
END;
$BODY$
;
