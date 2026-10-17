
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync(1);

    CREATE SCHEMA test_app;
    PERFORM hive.app_create_context( _name => 'test_ctx', _schema => 'test_app' );
    CREATE TABLE test_app.test_table( id INTEGER, val TEXT ) INHERITS( test_app.test_ctx );
    CREATE TABLE test_app.untouched_table( id INTEGER ) INHERITS( test_app.test_ctx );
    CREATE INDEX test_app_test_table_val_idx ON test_app.test_table( val );

    PERFORM hive.app_register_index_dependency(
        'test_ctx',
        'CREATE INDEX test_app_test_table_val_idx ON test_app.test_table( val )'
    );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_save_and_drop_indexes( 'test_ctx' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Index must be gone from the app schema
    ASSERT NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'test_app'
          AND indexname = 'test_app_test_table_val_idx'
    ), 'Index test_app_test_table_val_idx was NOT dropped (schema qualification bug)';

    -- Status must be 'missing' in the tracking table
    ASSERT (
        SELECT status FROM hafd.indexes_constraints
        WHERE index_constraint_name = 'test_app_test_table_val_idx'
    ) = 'missing', 'Index status should be missing after drop';

    -- Restore and verify the index comes back
    PERFORM hive.app_restore_indexes( 'test_ctx' );

    ASSERT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'test_app'
          AND indexname = 'test_app_test_table_val_idx'
    ), 'Index test_app_test_table_val_idx was NOT restored';

    ASSERT (
        SELECT array_agg(format('%s.%s:%s:%s', schema_name, table_name, kind, status) ORDER BY schema_name, table_name)
        FROM hafd.vacuum_requests
    ) = ARRAY['test_app.test_table:freeze:requested', 'test_app.untouched_table:freeze:requested']
    , 'app_restore_indexes(context) should request a freeze vacuum of every registered table of the context';

    DELETE FROM hafd.vacuum_requests;
    PERFORM hive.app_save_and_drop_indexes( 'test_ctx' );
    PERFORM hive.app_restore_indexes( 'test_ctx', 'test_app.test_table' );

    ASSERT (
        SELECT array_agg(format('%s.%s:%s:%s', schema_name, table_name, kind, status))
        FROM hafd.vacuum_requests
    ) = ARRAY['test_app.test_table:freeze:requested']
    , 'app_restore_indexes(context, table) should request a freeze vacuum of that table';
END;
$BODY$
;
