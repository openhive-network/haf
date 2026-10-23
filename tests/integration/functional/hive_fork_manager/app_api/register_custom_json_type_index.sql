-- The statement sql_serializer runs when hived meets a custom_json id it has no mapping for
CREATE OR REPLACE FUNCTION public.hived_meets_custom_json_id( _id SMALLINT, _custom_json_id TEXT )
RETURNS SMALLINT
LANGUAGE sql
AS
$BODY$
    INSERT INTO hafd.custom_json_types(id, custom_json_id) OVERRIDING SYSTEM VALUE VALUES( _id, _custom_json_id )
    ON CONFLICT (custom_json_id) DO UPDATE SET custom_json_id = EXCLUDED.custom_json_id RETURNING id;
$BODY$
;
GRANT EXECUTE ON FUNCTION public.hived_meets_custom_json_id TO test_hived;

CREATE OR REPLACE FUNCTION public.custom_json_type_indexes()
RETURNS TABLE( index_name TEXT, command TEXT, status hafd.index_status, contexts INT[] )
LANGUAGE sql
AS
$BODY$
    SELECT index_constraint_name, command, status, contexts
    FROM hafd.indexes_constraints
    WHERE table_name = 'hafd.operations' AND index_constraint_name LIKE 'hive\_operations\_custom\_json\_types\_%'
    ORDER BY index_constraint_name;
$BODY$
;

CREATE OR REPLACE FUNCTION public.expected_custom_json_type_index_command( _custom_json_ids TEXT[] )
RETURNS TEXT
LANGUAGE sql
AS
$BODY$
    SELECT format(
          'create index if not exists hive_operations_custom_json_types_%s_idx on hafd.operations (custom_json_type_id) where custom_json_type_id in (%s)'
        , replace( array_to_string( array_agg( id ORDER BY id ), '_' ), '-', 'n' )
        , array_to_string( array_agg( id ORDER BY id ), ',' )
    )
    FROM hafd.custom_json_types
    WHERE custom_json_id = ANY( _custom_json_ids );
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
    -- met by hived in massive sync, before the application asks for it
    ASSERT public.hived_meets_custom_json_id( 1::SMALLINT, 'reblog' ) = 1, 'reblog did not get the id hived assigned';
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

    PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'notify', 'follow', 'community', 'reblog', 'follow' ] );

    ASSERT ( SELECT array_agg( custom_json_id ORDER BY custom_json_id ) FROM hafd.custom_json_types WHERE id < 0 )
        = ARRAY[ 'community', 'follow', 'notify' ]::VARCHAR[], 'Types not met by hived yet did not get reserved ids';
    ASSERT ( SELECT count(*) FROM public.custom_json_type_indexes() ) = 1, 'Expected exactly one custom_json type index';
    ASSERT ( SELECT command FROM public.custom_json_type_indexes() )
        = public.expected_custom_json_type_index_command( ARRAY[ 'follow', 'reblog', 'community', 'notify' ] )
        , 'The index does not cover all requested types';
    ASSERT ( SELECT status FROM public.custom_json_type_indexes() ) = 'missing', 'The index should wait for the indexes controller';
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

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CALL public.build_missing_custom_json_type_indexes();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __reserved_follow_id SMALLINT;
BEGIN
    SELECT id INTO __reserved_follow_id FROM hafd.custom_json_types WHERE custom_json_id = 'follow';

    -- met live, after the application asked for it: hived adopts the reserved id
    ASSERT public.hived_meets_custom_json_id( 2::SMALLINT, 'follow' ) = __reserved_follow_id, 'hived did not adopt the reserved id of follow';
    ASSERT public.hived_meets_custom_json_id( 3::SMALLINT, 'some_game' ) = 3, 'A type nobody requested did not get the id hived assigned';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __indexes_before TEXT;
    __types_before TEXT;
BEGIN
    SELECT string_agg( format( '%s:%s:%s', index_name, status, contexts ), ',' ) INTO __indexes_before FROM public.custom_json_type_indexes();
    SELECT string_agg( format( '%s:%s', id, custom_json_id ), ',' ORDER BY id ) INTO __types_before FROM hafd.custom_json_types;

    -- an application restart
    PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'reblog', 'notify', 'community', 'follow' ] );

    ASSERT NOT EXISTS ( SELECT 1 FROM pg_locks WHERE pid = pg_backend_pid() AND relation = 'hafd.operations'::regclass )
        , 'A repeated request locked hafd.operations';
    ASSERT ( SELECT string_agg( format( '%s:%s:%s', index_name, status, contexts ), ',' ) FROM public.custom_json_type_indexes() ) = __indexes_before
        , 'A repeated request changed the registered indexes';
    ASSERT ( SELECT string_agg( format( '%s:%s', id, custom_json_id ), ',' ORDER BY id ) FROM hafd.custom_json_types ) = __types_before
        , 'A repeated request changed hafd.custom_json_types';

    PERFORM hive.register_custom_json_type_index( 'alice_ctx', ARRAY[ 'follow', 'reblog' ] );

    ASSERT ( SELECT count(*) FROM public.custom_json_type_indexes() ) = 2
        , 'The index of the previous set should stay until the new one is created';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __expected_command TEXT := public.expected_custom_json_type_index_command( ARRAY[ 'follow', 'reblog' ] );
BEGIN
    CALL public.build_missing_custom_json_type_indexes();

    ASSERT ( SELECT count(*) FROM public.custom_json_type_indexes() ) = 1, 'Only the index of the new set should remain registered';
    ASSERT ( SELECT command FROM public.custom_json_type_indexes() ) = __expected_command, 'The remaining index is not the one of the new set';
    ASSERT ( SELECT array_agg( indexname::TEXT ) FROM pg_indexes WHERE schemaname = 'hafd' AND indexname LIKE 'hive\_operations\_custom\_json\_types\_%' )
        = ARRAY[ ( SELECT index_name FROM public.custom_json_type_indexes() ) ]
        , 'Only the index of the new set should remain on hafd.operations';

    BEGIN
        PERFORM hive.create_custom_json_type_index( ARRAY[ 'notify' ] );
        ASSERT FALSE, 'hive.create_custom_json_type_index did not fail';
    EXCEPTION WHEN feature_not_supported THEN
    END;
    ASSERT ( SELECT count(*) FROM pg_indexes WHERE schemaname = 'hafd' AND indexname LIKE 'hive\_operations\_custom\_json\_types\_%' ) = 1
        , 'hive.create_custom_json_type_index created an index';
END;
$BODY$
;
