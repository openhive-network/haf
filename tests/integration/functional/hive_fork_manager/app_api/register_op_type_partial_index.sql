CREATE OR REPLACE FUNCTION public.op_type_index( _index_name TEXT )
RETURNS TABLE( command TEXT, status hafd.index_status, contexts INT[], massive_sync_class TEXT )
LANGUAGE sql
AS
$BODY$
    SELECT command, status, contexts, massive_sync_class
    FROM hafd.indexes_constraints
    WHERE table_name = 'hafd.operations' AND index_constraint_name = _index_name;
$BODY$
;

-- the lock a plain CREATE INDEX takes, which blocks hived's inserts into hafd.operations
CREATE OR REPLACE FUNCTION public.holds_share_lock_on_operations()
RETURNS BOOLEAN
LANGUAGE sql
AS
$BODY$
    SELECT EXISTS (
        SELECT 1 FROM pg_locks
        WHERE pid = pg_backend_pid() AND relation = 'hafd.operations'::regclass AND mode = 'ShareLock'
    );
$BODY$
;
GRANT EXECUTE ON FUNCTION public.holds_share_lock_on_operations TO PUBLIC;

CREATE OR REPLACE FUNCTION public.is_valid_operations_index( _index_name TEXT )
RETURNS BOOLEAN
LANGUAGE sql
AS
$BODY$
    SELECT EXISTS (
        SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname = _index_name AND i.indrelid = 'hafd.operations'::regclass AND i.indisvalid
    );
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES ( 1, 'hive::protocol::vote_operation', FALSE )
         , ( 2, 'hive::protocol::comment_operation', FALSE )
         , ( 3, 'hive::protocol::transfer_operation', FALSE );

    -- hived enters a massive sync
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    INSERT INTO hafd.operations(id, trx_in_block, op_type_id, op_pos, body_value)
    SELECT hafd.operation_id( b, p ), 0, 1 + p % 3, p, NULL
    FROM generate_series( 1, 100 ) b, generate_series( 0, 5 ) p;

    -- a node where an app already built the index of types 1 and 3 under its name
    EXECUTE 'CREATE INDEX hive_operations_op_types_1_3_idx ON hafd.operations (hafd.operation_id_to_block_num(id)) WHERE op_type_id IN (1,3)';
    CREATE TABLE public.existing_index AS SELECT 'hafd.hive_operations_op_types_1_3_idx'::regclass::oid AS index_oid;
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

    -- at install, before HAF leaves the massive sync
    PERFORM hive.register_op_type_partial_index( 'alice_ctx', ARRAY[ 2, 1 ]::SMALLINT[] );
    PERFORM hive.register_op_type_partial_index( 'alice_ctx', ARRAY[ 3, 1 ]::SMALLINT[] );
    ASSERT NOT public.holds_share_lock_on_operations(), 'The registration locked hafd.operations against hived''s inserts';

    BEGIN
        PERFORM hive.register_op_type_partial_index( 'alice_ctx', ARRAY[ 1, 99 ]::SMALLINT[] );
        ASSERT FALSE, 'An unknown operation type id was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
    END;

    BEGIN
        PERFORM hive.register_op_type_partial_index( 'alice_ctx', ARRAY[]::SMALLINT[] );
        ASSERT FALSE, 'An empty list of operation type ids was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA bob_app;
    PERFORM hive.app_create_context( _name => 'bob_ctx', _schema => 'bob_app' );
    PERFORM hive.register_op_type_partial_index( 'bob_ctx', ARRAY[ 1, 2, 2 ]::SMALLINT[] );

    BEGIN
        PERFORM hive.register_op_type_partial_index( 'alice_ctx', ARRAY[ 3 ]::SMALLINT[] );
        ASSERT FALSE, 'Bob registered an op type index for Alice''s context';
    EXCEPTION WHEN insufficient_privilege THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __alice INT := ( SELECT id FROM hafd.contexts WHERE name = 'alice_ctx' );
    __bob INT := ( SELECT id FROM hafd.contexts WHERE name = 'bob_ctx' );
    __index RECORD;
BEGIN
    SELECT * INTO __index FROM public.op_type_index( 'hive_operations_op_types_1_2_idx' );
    ASSERT __index.command = 'create index if not exists hive_operations_op_types_1_2_idx on hafd.operations (hafd.operation_id_to_block_num(id)) where op_type_id in (1,2)'
        , format( 'Unexpected command of the registered index: %s', __index.command );
    ASSERT __index.status = 'missing', 'The index registered before LIVE was built by its requester';
    ASSERT __index.contexts = ARRAY[ __alice, __bob ], format( 'The contexts requesting the same types do not share the index: %s', __index.contexts );
    ASSERT __index.massive_sync_class = 'keep', format( 'The registered index has the massive sync class %s', __index.massive_sync_class );
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_indexes WHERE indexname = 'hive_operations_op_types_1_2_idx' ), 'The index was built before LIVE entry';

    SELECT * INTO __index FROM public.op_type_index( 'hive_operations_op_types_1_3_idx' );
    ASSERT __index.status = 'created', 'The index existing under its name was not recognised as created';
    ASSERT __index.contexts = ARRAY[ __alice ], format( 'Unexpected contexts of the existing index: %s', __index.contexts );

    -- hived enters LIVE
    PERFORM hive.enable_indexes_of_irreversible();
    PERFORM hive.enable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- after LIVE
    PERFORM hive.register_op_type_partial_index( 'alice_ctx', ARRAY[ 3 ]::SMALLINT[] );
    ASSERT NOT public.holds_share_lock_on_operations(), 'The registration after LIVE locked hafd.operations against hived''s inserts';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- deprecated, requests the index without a context (and raises a WARNING, which cannot be caught here)
    PERFORM hive.create_op_type_partial_index( ARRAY[ 3, 2 ]::SMALLINT[] );
    ASSERT NOT public.holds_share_lock_on_operations(), 'hive.create_op_type_partial_index locked hafd.operations against hived''s inserts';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __index RECORD;
BEGIN
    ASSERT ( SELECT status FROM public.op_type_index( 'hive_operations_op_types_1_2_idx' ) ) = 'created'
        , 'The restore at LIVE entry did not mark the index created';
    ASSERT public.is_valid_operations_index( 'hive_operations_op_types_1_2_idx' ), 'The restore at LIVE entry did not build the index';
    ASSERT ( SELECT 'hafd.hive_operations_op_types_1_3_idx'::regclass::oid ) = ( SELECT index_oid FROM public.existing_index )
        , 'The index existing under its name was rebuilt';

    -- left to hived's indexes controller, which builds it with CREATE INDEX CONCURRENTLY
    ASSERT ( SELECT status FROM public.op_type_index( 'hive_operations_op_types_3_idx' ) ) = 'missing'
        , 'The index registered after LIVE is not waiting for the indexes controller';
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_indexes WHERE indexname = 'hive_operations_op_types_3_idx' ), 'The index registered after LIVE was built by its requester';

    SELECT * INTO __index FROM public.op_type_index( 'hive_operations_op_types_2_3_idx' );
    ASSERT __index.status = 'missing', 'hive.create_op_type_partial_index did not leave its index to the indexes controller';
    ASSERT __index.contexts = '{}'::INT[], format( 'hive.create_op_type_partial_index registered contexts %s', __index.contexts );
    ASSERT __index.massive_sync_class = 'keep', format( 'hive.create_op_type_partial_index registered the massive sync class %s', __index.massive_sync_class );
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_indexes WHERE indexname = 'hive_operations_op_types_2_3_idx' ), 'hive.create_op_type_partial_index built its index';

    ASSERT ( SELECT array_agg( index_constraint_name ORDER BY index_constraint_name ) FROM hive.missing_index_builds( 1000, '6 hours' ) )
        = ARRAY[ 'hive_operations_op_types_2_3_idx', 'hive_operations_op_types_3_idx' ]
        , 'The indexes controller would not build the indexes requested after LIVE';

    PERFORM hive.remove_index_dependencies( 'bob_ctx' );
    ASSERT public.is_valid_operations_index( 'hive_operations_op_types_1_2_idx' ), 'Removing one context dropped the index another context needs';

    PERFORM hive.remove_index_dependencies( 'alice_ctx' );
    ASSERT NOT EXISTS ( SELECT 1 FROM pg_indexes WHERE indexname = 'hive_operations_op_types_1_2_idx' ), 'The index no context needs was not dropped';
END;
$BODY$
;
