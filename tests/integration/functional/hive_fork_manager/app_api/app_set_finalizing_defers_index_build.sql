CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice_app;
    PERFORM hive.app_create_context( _name => 'alice_ctx', _schema => 'alice_app' );
    PERFORM hive.app_create_context( _name => 'alice_registering_ctx', _schema => 'alice_app' );
    PERFORM hive.app_register_index_dependency( 'alice_registering_ctx', 'CREATE INDEX alice_operations_trx_in_block_idx ON hafd.operations ( trx_in_block )' );

    ASSERT ( SELECT deferred_by FROM hive.missing_index_builds( 1000, '6 hours' ) WHERE index_constraint_name = 'alice_operations_trx_in_block_idx' ) IS NULL
        , 'The build is deferred while no context is finalizing';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_set_finalizing( ARRAY[ 'alice_ctx' ] );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_error()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_set_finalizing( ARRAY[ 'alice_ctx' ], FALSE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT is_finalizing FROM hafd.contexts WHERE name = 'alice_ctx' ), 'Bob cleared the finalizing flag of Alice''s context';
    ASSERT ( SELECT deferred_by FROM hive.missing_index_builds( 1000, '6 hours' ) WHERE index_constraint_name = 'alice_operations_trx_in_block_idx' ) = ARRAY[ 'alice_ctx' ]
        , 'The build is not deferred by the finalizing context';

    PERFORM hive.app_set_finalizing( ARRAY[ 'alice_ctx' ], FALSE );
    ASSERT ( SELECT deferred_by FROM hive.missing_index_builds( 1000, '6 hours' ) WHERE index_constraint_name = 'alice_operations_trx_in_block_idx' ) IS NULL
        , 'The build is still deferred after the flag was cleared';

    BEGIN
        PERFORM hive.app_set_finalizing( ARRAY[ 'alice_ctx', 'no_such_ctx' ] );
        ASSERT FALSE, 'A group with a nonexistent context was accepted';
    EXCEPTION WHEN raise_exception THEN
    END;
END;
$BODY$
;
