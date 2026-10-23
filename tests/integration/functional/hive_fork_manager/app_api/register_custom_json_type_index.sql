-- The statement sql_serializer runs when hived meets a custom_json id it has no mapping for
CREATE OR REPLACE PROCEDURE public.hived_meets_custom_json_id( _id SMALLINT, _custom_json_id TEXT )
LANGUAGE sql
AS
$BODY$
    INSERT INTO hafd.custom_json_types(id, custom_json_id) OVERRIDING SYSTEM VALUE VALUES( _id, _custom_json_id ) ON CONFLICT DO NOTHING;
$BODY$
;
GRANT EXECUTE ON PROCEDURE public.hived_meets_custom_json_id TO test_hived;

CREATE OR REPLACE FUNCTION public.custom_json_type_indexes()
RETURNS TABLE( index_name TEXT, command TEXT, status hafd.index_status, contexts INT[] )
LANGUAGE sql
AS
$BODY$
    SELECT index_constraint_name, command, status, contexts
    FROM hafd.indexes_constraints
    WHERE table_name = 'hafd.operations' AND index_constraint_name LIKE 'hive\_operations\_custom\_json\_%'
    ORDER BY index_constraint_name;
$BODY$
;
GRANT EXECUTE ON FUNCTION public.custom_json_type_indexes TO test_hived;

CREATE OR REPLACE FUNCTION public.custom_json_type_indexes_snapshot()
RETURNS TEXT
LANGUAGE sql
AS
$BODY$
    SELECT string_agg( format( '%s:%s:%s', index_name, status, contexts ), ',' ) FROM public.custom_json_type_indexes();
$BODY$
;

CREATE OR REPLACE FUNCTION public.explain_lines( _query TEXT )
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    RETURN QUERY EXECUTE 'EXPLAIN ' || _query;
END;
$BODY$
;

-- What hived's indexes controller does with a missing index (without CONCURRENTLY, which cannot run in a procedure)
CREATE OR REPLACE PROCEDURE public.build_missing_custom_json_type_indexes()
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __index RECORD;
BEGIN
    FOR __index IN SELECT * FROM public.custom_json_type_indexes() WHERE status = 'missing'
    LOOP
        UPDATE hafd.indexes_constraints SET status = 'creating' WHERE index_constraint_name = __index.index_name;
        EXECUTE __index.command;
        UPDATE hafd.indexes_constraints SET status = 'created' WHERE index_constraint_name = __index.index_name;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- custom_json operations of blocks 1..1000: 'follow' (id 1) in every block, 'NFT' (id 3) in every 100th,
    -- the rest of a spammy type (id 2)
    INSERT INTO hafd.operations(id, trx_in_block, op_type_id, op_pos, body_value, custom_json_type_id)
    SELECT hafd.operation_id( b, p ), 0, 18, p, NULL
         , CASE WHEN p = 0 THEN 1 WHEN p = 1 AND b % 100 = 0 THEN 3 ELSE 2 END
    FROM generate_series( 1, 1000 ) b, generate_series( 0, 49 ) p;
    ANALYZE hafd.operations;

    -- met by hived before any application asks for it
    CALL public.hived_meets_custom_json_id( 1::SMALLINT, 'follow' );
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

    PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'NFT', 'follow' ] );

    ASSERT public.custom_json_type_indexes_snapshot() IS NULL, 'An index was registered before all requested types appeared';
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.custom_json_types WHERE custom_json_id = 'NFT' ), 'The request created a type id';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    BEGIN
        PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'follow' ] );
        ASSERT FALSE, 'Bob registered a custom_json type index for Alice''s context';
    EXCEPTION WHEN insufficient_privilege THEN
    END;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL public.hived_meets_custom_json_id( 2::SMALLINT, 'some_game' );
    ASSERT ( SELECT count(*) FROM public.custom_json_type_indexes() ) = 0, 'An index was registered before all requested types appeared';

    CALL public.hived_meets_custom_json_id( 3::SMALLINT, 'NFT' );
    ASSERT ( SELECT count(*) FROM public.custom_json_type_indexes() ) = 1, 'Expected exactly one index once the last requested type appeared';
    ASSERT ( SELECT command FROM public.custom_json_type_indexes() )
        = 'create index if not exists hive_operations_custom_json_block_num_1_3_idx on hafd.operations (hafd.operation_id_to_block_num(id)) where custom_json_type_id in (1,3)'
        , 'The index does not cover all requested types keyed on block number';
    ASSERT ( SELECT status FROM public.custom_json_type_indexes() ) = 'missing', 'The index should wait for the indexes controller';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __indexes_before TEXT := public.custom_json_type_indexes_snapshot();
BEGIN
    -- an application restart
    PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'follow', 'NFT', 'follow' ] );

    ASSERT public.custom_json_type_indexes_snapshot() = __indexes_before, 'A repeated request changed the registered indexes';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __indexes_before TEXT;
    __plan TEXT;
BEGIN
    CALL public.build_missing_custom_json_type_indexes();
    ASSERT EXISTS ( SELECT 1 FROM pg_indexes WHERE schemaname = 'hafd' AND indexname = 'hive_operations_custom_json_block_num_1_3_idx' )
        , 'The registered index was not built';

    -- an application restart once the index is built
    __indexes_before := public.custom_json_type_indexes_snapshot();
    PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'NFT', 'follow' ] );
    ASSERT public.custom_json_type_indexes_snapshot() = __indexes_before, 'A repeated request changed the built index';

    SET LOCAL enable_seqscan = off;
    SELECT string_agg( line, E'\n' ) INTO __plan
    FROM public.explain_lines( 'SELECT id FROM hafd.operations WHERE hafd.operation_id_to_block_num(id) BETWEEN 100 AND 300 AND custom_json_type_id = 3' ) AS line;
    ASSERT __plan LIKE '%hive_operations_custom_json_block_num_1_3_idx%', format( 'A block-range scan of NFT did not use the index: %s', __plan );
    RESET enable_seqscan;

    -- the application changes its set
    PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'NFT' ] );
    ASSERT ( SELECT array_agg( index_name ORDER BY index_name ) FROM public.custom_json_type_indexes() )
        = ARRAY[ 'hive_operations_custom_json_block_num_1_3_idx', 'hive_operations_custom_json_block_num_3_idx' ]
        , 'The index of the previous set should stay until the new one is built';

    CALL public.build_missing_custom_json_type_indexes();
    ASSERT ( SELECT array_agg( index_name ) FROM public.custom_json_type_indexes() ) = ARRAY[ 'hive_operations_custom_json_block_num_3_idx' ]
        , 'Only the index of the new set should remain registered';
    ASSERT ( SELECT array_agg( indexname::TEXT ) FROM pg_indexes WHERE schemaname = 'hafd' AND indexname LIKE 'hive\_operations\_custom\_json\_%' )
        = ARRAY[ 'hive_operations_custom_json_block_num_3_idx' ]
        , 'Only the index of the new set should remain on hafd.operations';

    -- deprecated, still builds its index (and raises a WARNING, which cannot be caught here)
    PERFORM hive.create_custom_json_type_index( ARRAY[ 'follow' ] );
    ASSERT EXISTS ( SELECT 1 FROM pg_indexes WHERE schemaname = 'hafd' AND indexname = 'hive_operations_custom_json_types_1_idx' )
        , 'hive.create_custom_json_type_index did not create its index';
END;
$BODY$
;
