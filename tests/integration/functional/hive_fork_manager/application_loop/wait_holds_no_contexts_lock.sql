-- An application waiting in hive.app_next_iteration for the next block (_wait => TRUE, as the eternal
-- CALL main() loops do) has committed the iteration first: while it waits it holds no lock on
-- hafd.contexts and not the gate of hived's compaction of the table, see
-- hive.contexts_compaction_gate_key. The application runs in its own session (dblink).

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'forking', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'nonforking', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    CREATE TABLE public.samples( context TEXT, wait_event TEXT, contexts_locks BIGINT, advisory_locks BIGINT );

    FOR __block IN 1 .. 3 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL
            , CASE WHEN __block = 1 THEN ARRAY[ ( 5, 'initminer', 1 )::hafd.accounts ] ELSE NULL END
            , NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 3 );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 3 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __i INTEGER;
    __ctx TEXT;
    __app_pid INTEGER;
BEGIN
    FOREACH __ctx IN ARRAY ARRAY[ 'forking', 'nonforking' ] LOOP
        FOR __i IN 1 .. 10 LOOP
            CALL hive.app_next_iteration( ARRAY[ __ctx ], __blocks, _wait => FALSE );
            EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = __ctx ) = 3;
        END LOOP;
        ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = __ctx ) = 3, __ctx || ' did not reach the head';
    END LOOP;
    COMMIT;

    PERFORM dblink_connect( 'app', format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );
    __app_pid := ( SELECT pid FROM dblink( 'app', 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) );

    FOREACH __ctx IN ARRAY ARRAY[ 'forking', 'nonforking' ] LOOP
        -- the XID makes the first call commit, as in a loop that has processed a range before;
        -- no block arrives, so every iteration waits for one
        PERFORM dblink_send_query( 'app', format(
            'DO $do$ DECLARE __r hive.blocks_range; __start TIMESTAMPTZ := clock_timestamp(); BEGIN PERFORM pg_current_xact_id(); '
            || 'WHILE clock_timestamp() - __start < INTERVAL ''4 seconds'' LOOP CALL hive.app_next_iteration( ARRAY[ %L ], __r ); END LOOP; END $do$', __ctx ) );

        FOR __i IN 1 .. 60 LOOP
            PERFORM pg_sleep( 0.05 );
            INSERT INTO public.samples
            SELECT __ctx
                 , ( SELECT a.wait_event_type || '/' || a.wait_event FROM pg_stat_activity a WHERE a.pid = __app_pid )
                 , ( SELECT COUNT(*) FROM pg_locks WHERE pid = __app_pid AND locktype = 'relation' AND relation = 'hafd.contexts'::REGCLASS )
                 , ( SELECT COUNT(*) FROM pg_locks WHERE pid = __app_pid AND locktype = 'advisory' );
        END LOOP;

        PERFORM * FROM dblink_get_result( 'app' ) AS t( status TEXT );
        PERFORM * FROM dblink_get_result( 'app' ) AS t( status TEXT );
    END LOOP;

    PERFORM dblink_disconnect( 'app' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __row RECORD;
BEGIN
    FOR __row IN
        SELECT context
             , COUNT(*) FILTER ( WHERE waiting ) AS waiting
             , COUNT(*) FILTER ( WHERE waiting AND ( contexts_locks > 0 OR advisory_locks > 0 ) ) AS waiting_with_locks
             , string_agg( DISTINCT wait_event, ', ' ) AS wait_events
        FROM ( SELECT *, wait_event IN ( 'Extension/Extension', 'Timeout/PgSleep' ) AS waiting FROM public.samples ) s
        GROUP BY context
    LOOP
        RAISE NOTICE '%: % samples waiting, % of them with locks; wait events: %', __row.context, __row.waiting, __row.waiting_with_locks, __row.wait_events;
        ASSERT __row.waiting >= 30, format( '%s: the iterations waited in only %s of 60 samples (%s)', __row.context, __row.waiting, __row.wait_events );
        -- a sample may catch the next iteration between reading the wait event and the locks
        ASSERT __row.waiting_with_locks <= 3
            , format( '%s: %s of %s samples caught a waiting iteration holding a lock on hafd.contexts or the compaction gate', __row.context, __row.waiting_with_locks, __row.waiting );
    END LOOP;
    ASSERT ( SELECT COUNT( DISTINCT context ) FROM public.samples ) = 2, 'both loop flavours must have been sampled';
END;
$BODY$
;
