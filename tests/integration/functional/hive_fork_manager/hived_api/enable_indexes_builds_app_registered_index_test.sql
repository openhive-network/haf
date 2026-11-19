CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- hived enters a massive sync
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- the application registers its index on a HAF table at install, before HAF leaves the massive sync
    CREATE SCHEMA alice_app;
    PERFORM hive.app_create_context( _name => 'alice_ctx', _schema => 'alice_app' );
    PERFORM hive.app_register_index_dependency( 'alice_ctx', 'CREATE INDEX alice_operations_trx_in_block_idx ON hafd.operations ( trx_in_block )' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT status FROM hafd.indexes_constraints WHERE index_constraint_name = 'alice_operations_trx_in_block_idx' ) = 'missing'
        , 'The registered index is not missing before LIVE entry';

    -- hived enters LIVE
    PERFORM hive.enable_indexes_of_irreversible();
    PERFORM hive.enable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT status FROM hafd.indexes_constraints WHERE index_constraint_name = 'alice_operations_trx_in_block_idx' ) = 'created'
        , 'The restore did not mark the app-registered index created';
    ASSERT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indexrelid = 'hafd.alice_operations_trx_in_block_idx'::regclass
          AND i.indrelid = 'hafd.operations'::regclass
          AND i.indisvalid
    ), 'The restore did not build the app-registered index on hafd.operations';
    ASSERT NOT EXISTS ( SELECT 1 FROM hive.missing_index_builds( 1000, '6 hours' ) )
        , 'The monitor would still build an index concurrently after the restore';
END;
$BODY$
;
