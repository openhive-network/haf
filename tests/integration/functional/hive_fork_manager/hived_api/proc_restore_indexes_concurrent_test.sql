-- hive.proc_restore_indexes of hafd.operations with two helpers (hive.proc_help_restore_indexes) in other
-- sessions, as hived runs them: held up by this session's lock on the table, the three sessions each build
-- one of its plain indexes at once, the three that hive.index_restore_order puts first, and once let
-- through they build every index, each committed on its own.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __command TEXT;
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    -- the kinds of index the applications have hafd.operations carry: on the operation body, partial
    CREATE INDEX test_operations_body_author ON hafd.operations ( ( body_value ->> 'author' ) ) WHERE op_type_id = 1;
    CREATE INDEX test_operations_body_author_permlink ON hafd.operations ( ( body_value ->> 'author' ), ( body_value ->> 'permlink' ) )
        WHERE op_type_id = ANY( ARRAY[ 0, 1, 17 ] );
    CREATE INDEX test_operations_op_types_idx ON hafd.operations ( hafd.operation_id_to_block_num( id ) ) WHERE op_type_id = ANY( ARRAY[ 17, 61, 72 ] );
    CREATE INDEX test_operations_custom_json_idx ON hafd.operations ( hafd.operation_id_to_block_num( id ) ) WHERE custom_json_type_id = 7;
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible();

    INSERT INTO hafd.operations( id, trx_in_block, op_type_id, op_pos, body_value, custom_json_type_id )
    SELECT ( ( i / 10 )::BIGINT << 32 ) | ( i % 10 ), 0, i % 80, i % 10
         , jsonb_build_object( 'author', 'a' || ( i % 97 ), 'permlink', 'p' || i ), CASE WHEN i % 7 = 0 THEN 7 END
    FROM generate_series( 1, 20000 ) i;

    -- only the plain indexes are left, which the sessions build at once
    FOR __command IN SELECT command FROM hafd.indexes_constraints
                     WHERE table_name = 'hafd.operations' AND is_constraint AND status = 'missing' LOOP
        PERFORM hive.restore_index( __command );
    END LOOP;
    PERFORM hive.restore_not_null_constraints( 'hafd.operations' );
    ASSERT ( SELECT count(*) FROM hafd.indexes_constraints
             WHERE table_name = 'hafd.operations' AND is_index AND NOT is_constraint AND status = 'missing' ) >= 6,
        'hafd.operations has too few plain indexes to restore';
    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints
                       WHERE table_name = 'hafd.operations' AND NOT is_foreign_key AND NOT is_index AND status = 'missing' ),
        'A constraint of hafd.operations is left to restore';

    CREATE TABLE public.claimed( index_constraint_name TEXT );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __connection TEXT := format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) );
    __pids INTEGER[];
    __i INTEGER;
BEGIN
    PERFORM dblink_connect( 'restorer', __connection );
    PERFORM dblink_connect( 'helper1', __connection );
    PERFORM dblink_connect( 'helper2', __connection );
    __pids := ARRAY[
          ( SELECT pid FROM dblink( 'restorer', 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) )
        , ( SELECT pid FROM dblink( 'helper1', 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) )
        , ( SELECT pid FROM dblink( 'helper2', 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) ) ];

    -- holds up every index build (CREATE INDEX takes a SHARE lock) until this transaction ends
    LOCK TABLE hafd.operations IN ROW EXCLUSIVE MODE;
    -- taken before the helpers start, as hived does
    PERFORM * FROM dblink( 'restorer', 'SELECT pg_advisory_lock( hive.index_restore_lock_key( ''hafd.operations'' ) )' ) AS t( l TEXT );
    PERFORM dblink_send_query( 'helper1', 'CALL hive.proc_help_restore_indexes( ''hafd.operations'' )' );
    PERFORM dblink_send_query( 'helper2', 'CALL hive.proc_help_restore_indexes( ''hafd.operations'' )' );
    PERFORM dblink_send_query( 'restorer', 'CALL hive.proc_restore_indexes( ''hafd.operations'' )' );

    FOR __i IN 1 .. 600 LOOP
        EXIT WHEN ( SELECT bool_and( pg_backend_pid() = ANY( pg_blocking_pids( p ) ) ) FROM unnest( __pids ) p );
        PERFORM pg_sleep( 0.1 );
    END LOOP;
    ASSERT ( SELECT bool_and( pg_backend_pid() = ANY( pg_blocking_pids( p ) ) ) FROM unnest( __pids ) p ),
        'The restore and its helpers did not all start an index build';

    -- the rows that the sessions' uncommitted transactions claimed
    INSERT INTO public.claimed
    SELECT ic.index_constraint_name FROM hafd.indexes_constraints ic
    WHERE ic.table_name = 'hafd.operations'
      AND ic.xmax::TEXT IN ( SELECT backend_xid::TEXT FROM pg_stat_activity WHERE pid = ANY( __pids ) );
    COMMIT;

    -- raise the restore's or a helper's error, if it failed
    PERFORM * FROM dblink_get_result( 'restorer' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'restorer' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'helper1' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'helper1' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'helper2' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'helper2' ) AS t( status TEXT );
    PERFORM dblink_disconnect( 'restorer' );
    PERFORM dblink_disconnect( 'helper1' );
    PERFORM dblink_disconnect( 'helper2' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT count(*) FROM public.claimed ) = 3, 'The three sessions did not each build an index at once';
    ASSERT NOT EXISTS(
        ( SELECT index_constraint_name FROM public.claimed )
        EXCEPT
        ( SELECT index_constraint_name FROM hafd.indexes_constraints
          WHERE table_name = 'hafd.operations' AND is_index AND NOT is_constraint
          ORDER BY hive.index_restore_order( command ), index_constraint_name LIMIT 3 )
    ), 'The sessions did not build the indexes estimated longest first';
    ASSERT ( SELECT count(*) FROM public.claimed
             WHERE index_constraint_name IN ( 'test_operations_body_author', 'test_operations_body_author_permlink' ) ) = 2,
        'The indexes on the operation body were not built first';

    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints WHERE table_name = 'hafd.operations' AND is_foreign_key = FALSE AND status != 'created' ),
        'Not every index of hafd.operations was restored';
    ASSERT ( SELECT count( DISTINCT xmin::TEXT ) = count(*) FROM hafd.indexes_constraints
             WHERE table_name = 'hafd.operations' AND is_index AND NOT is_constraint ),
        'Two indexes of hafd.operations were restored in one transaction';
    ASSERT NOT EXISTS( SELECT 1 FROM hafd.indexes_constraints ic
                       WHERE ic.table_name = 'hafd.operations' AND ( ic.is_index OR ic.is_constraint )
                         AND NOT EXISTS( SELECT 1 FROM pg_index i
                                         WHERE i.indexrelid = to_regclass( 'hafd.' || ic.index_constraint_name ) AND i.indisvalid ) ),
        'An index of hafd.operations is missing or invalid';
    ASSERT ( SELECT count(*) FROM pg_index WHERE indrelid = 'hafd.operations'::regclass )
         = ( SELECT count(*) FROM hafd.indexes_constraints WHERE table_name = 'hafd.operations' AND ( is_index OR is_constraint ) ),
        'hafd.operations has another number of indexes than it had saved';
END;
$BODY$
;
