-- The application and hived run in their own sessions (dblink), so their transactions overlap as they do in production.

CREATE OR REPLACE FUNCTION public.connect_as( _connection TEXT, _user TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM dblink_connect( _connection, format( 'host=localhost port=%s dbname=%s user=%s password=test'
        , current_setting( 'port' ), current_database(), _user ) );
END;
$BODY$
;

-- The statement sql_serializer runs when hived meets a custom_json id it has no mapping for.
-- With a low lock_timeout, it fails instead of waiting on a lock.
CREATE OR REPLACE FUNCTION public.hived_meets_custom_json_id( _id INT, _custom_json_id TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM dblink_exec( 'hived', format(
        'INSERT INTO hafd.custom_json_types(id, custom_json_id) OVERRIDING SYSTEM VALUE VALUES( %s, %L ) ON CONFLICT DO NOTHING'
        , _id, _custom_json_id ) );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.app_requests( _context TEXT, _custom_json_ids TEXT[] )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM * FROM dblink( 'app', format( 'SELECT hive.register_custom_json_type_index( %L, %L )', _context, _custom_json_ids ) ) AS t( r TEXT );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.app_asks_for_next_block( _context TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM * FROM dblink( 'app', format( 'SELECT hive.app_next_block( ARRAY[ %L ]::hive.contexts_group, FALSE )', _context ) ) AS t( r TEXT );
END;
$BODY$
;

-- The custom_json type indexes registered for the context, one row per context entry
CREATE OR REPLACE FUNCTION public.registered_indexes_of( _context TEXT )
RETURNS TEXT[]
LANGUAGE sql
AS
$BODY$
    SELECT COALESCE( array_agg( ic.index_constraint_name ORDER BY ic.index_constraint_name ), '{}' )
    FROM hafd.indexes_constraints ic
    JOIN hafd.contexts c ON c.name = _context
    CROSS JOIN LATERAL unnest( ic.contexts ) AS ctx( id )
    WHERE ic.table_name = 'hafd.operations' AND ic.index_constraint_name LIKE 'hive\_operations\_custom\_json\_%' AND ctx.id = c.id;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice_app;
    PERFORM hive.app_create_context( _name => 'request_after_type_ctx', _schema => 'alice_app' );
    PERFORM hive.app_create_context( _name => 'type_after_request_ctx', _schema => 'alice_app' );
    PERFORM hive.app_create_context( _name => 'repeated_request_ctx', _schema => 'alice_app' );

    PERFORM hive.register_custom_json_type_index( 'repeated_request_ctx', ARRAY[ 'NFT_C' ] );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __advisory_locks INT;
BEGIN
    PERFORM public.connect_as( 'app', 'alice' );
    PERFORM public.connect_as( 'hived', 'test_hived' );
    PERFORM dblink_exec( 'hived', 'SET lock_timeout = ''200ms''' );
    -- the application may wait for hived, but not forever if hived waits for it
    PERFORM dblink_exec( 'app', 'SET lock_timeout = ''5s''' );

    -- no request waits for this type: its insert takes no advisory lock
    PERFORM dblink_exec( 'hived', 'BEGIN' );
    PERFORM public.hived_meets_custom_json_id( 10, 'no_one_wants_it' );
    SELECT n INTO __advisory_locks FROM dblink( 'hived', 'SELECT count(*)::INT FROM pg_locks WHERE pid = pg_backend_pid() AND locktype = ''advisory''' ) AS t( n INT );
    PERFORM dblink_exec( 'hived', 'COMMIT' );
    ASSERT __advisory_locks = 0, format( 'Storing a type no request waits for took %s advisory locks', __advisory_locks );

    -- the request stays open while hived stores its types, and an unrelated one: hived does not wait
    PERFORM dblink_exec( 'app', 'BEGIN' );
    PERFORM public.app_requests( 'request_after_type_ctx', ARRAY[ 'NFT_A', 'GAME_A' ] );
    PERFORM public.hived_meets_custom_json_id( 11, 'unrelated_a' );
    PERFORM public.hived_meets_custom_json_id( 12, 'NFT_A' );
    PERFORM public.hived_meets_custom_json_id( 13, 'GAME_A' );
    PERFORM dblink_exec( 'app', 'COMMIT' );

    -- the request commits before hived's transaction storing its last type
    PERFORM dblink_exec( 'hived', 'BEGIN' );
    PERFORM public.hived_meets_custom_json_id( 14, 'NFT_B' );
    PERFORM dblink_exec( 'app', 'BEGIN' );
    PERFORM public.app_requests( 'type_after_request_ctx', ARRAY[ 'NFT_B' ] );
    PERFORM dblink_exec( 'app', 'COMMIT' );
    PERFORM dblink_exec( 'hived', 'COMMIT' );

    -- an application repeats its committed request in an open transaction, locking it, while hived stores its type
    PERFORM dblink_exec( 'app', 'BEGIN' );
    PERFORM public.app_requests( 'repeated_request_ctx', ARRAY[ 'NFT_C' ] );
    PERFORM public.hived_meets_custom_json_id( 15, 'NFT_C' );
    PERFORM dblink_exec( 'app', 'COMMIT' );

    PERFORM dblink_disconnect( 'hived' );
    PERFORM dblink_disconnect( 'app' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- the application's next block request registers the requests whose last type raced with them
    PERFORM public.connect_as( 'app', 'alice' );
    PERFORM public.app_asks_for_next_block( 'request_after_type_ctx' );
    PERFORM public.app_asks_for_next_block( 'type_after_request_ctx' );
    PERFORM public.app_asks_for_next_block( 'repeated_request_ctx' );
    PERFORM public.app_asks_for_next_block( 'request_after_type_ctx' );
    PERFORM public.app_asks_for_next_block( 'type_after_request_ctx' );
    PERFORM public.app_asks_for_next_block( 'repeated_request_ctx' );
    PERFORM dblink_disconnect( 'app' );

    ASSERT public.registered_indexes_of( 'request_after_type_ctx' ) = ARRAY[ 'hive_operations_custom_json_block_num_12_13_idx' ]
        , format( 'request committed after the type: expected exactly one index, got %s', public.registered_indexes_of( 'request_after_type_ctx' ) );
    ASSERT public.registered_indexes_of( 'type_after_request_ctx' ) = ARRAY[ 'hive_operations_custom_json_block_num_14_idx' ]
        , format( 'type committed after the request: expected exactly one index, got %s', public.registered_indexes_of( 'type_after_request_ctx' ) );
    ASSERT public.registered_indexes_of( 'repeated_request_ctx' ) = ARRAY[ 'hive_operations_custom_json_block_num_15_idx' ]
        , format( 'repeated request: expected exactly one index, got %s', public.registered_indexes_of( 'repeated_request_ctx' ) );
    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.custom_json_type_index_requests WHERE index_name IS NULL )
        , 'Some request is still pending';
END;
$BODY$
;
