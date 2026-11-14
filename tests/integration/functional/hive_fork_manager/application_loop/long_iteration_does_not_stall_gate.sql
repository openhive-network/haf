-- An application that holds the gate of hived's compaction of hafd.contexts (hive.contexts_compaction_gate_key)
-- shared for longer than the compaction's gate timeout does not hold the other applications back: hived,
-- as contexts_compactor runs it, polls pg_try_advisory_lock instead of queueing for the key, so another
-- application's iterations keep entering the gate at once. The control case queues an exclusive request,
-- as pg_advisory_lock does, and shows the other application's iteration waiting behind it.
-- The applications and hived run in their own sessions (dblink).

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

CREATE OR REPLACE FUNCTION public.connect_as_admin( _connection TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM dblink_connect( _connection, format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.backend_pid( _connection TEXT )
RETURNS INTEGER
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    RETURN ( SELECT pid FROM dblink( _connection, 'SELECT pg_backend_pid()' ) AS t( pid INTEGER ) );
END;
$BODY$
;

-- contexts_compactor::enter_gate: try the key every 50 ms until the timeout, never queue for it
CREATE OR REPLACE FUNCTION public.poll_gate( _timeout INTERVAL )
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __deadline TIMESTAMPTZ := clock_timestamp() + _timeout;
BEGIN
    LOOP
        IF pg_try_advisory_lock( hive.contexts_compaction_gate_key() ) THEN
            PERFORM pg_advisory_unlock( hive.contexts_compaction_gate_key() );
            RETURN TRUE;
        END IF;
        EXIT WHEN clock_timestamp() >= __deadline;
        PERFORM pg_sleep( 0.05 );
    END LOOP;
    RETURN FALSE;
END;
$BODY$
;

-- one iteration of the other application, as an application at the head runs it
CREATE OR REPLACE FUNCTION public.timed_iteration()
RETURNS INTERVAL
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __started_at TIMESTAMPTZ := clock_timestamp();
BEGIN
    PERFORM * FROM dblink( 'other', 'CALL hive.app_next_iteration( ARRAY[ ''other_app'' ], NULL, _wait => FALSE )' ) AS t( blocks TEXT );
    RETURN clock_timestamp() - __started_at;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'long_app', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'other_app', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    CREATE TABLE public.results( phase TEXT, iterations INTEGER, longest_iteration INTERVAL, compactor_entered BOOLEAN );

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
    __long_pid INTEGER;
    __iterations INTEGER;
    __longest INTERVAL;
    __entered BOOLEAN;
BEGIN
    FOR __i IN 1 .. 10 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'other_app' ], __blocks, _wait => FALSE );
        EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'other_app' ) = 3;
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'other_app' ) = 3, 'other_app did not reach the head';
    COMMIT;

    PERFORM public.connect_as_admin( 'long' );
    PERFORM public.connect_as_admin( 'other' );
    PERFORM public.connect_as( 'hived', 'test_hived' );
    __long_pid := public.backend_pid( 'long' );

    -- an iteration that processes its range for 9 s, holding the gate shared
    PERFORM dblink_send_query( 'long',
        'SELECT ''done'' FROM ( SELECT hive.app_enter_contexts_gate(), pg_sleep( 9 ) ) AS t' );
    PERFORM pg_sleep( 0.3 );
    ASSERT EXISTS ( SELECT 1 FROM pg_locks WHERE pid = __long_pid AND locktype = 'advisory' AND granted ),
        'the long iteration does not hold the gate';

    -- hived polls for the gate for 2 s while the other application iterates
    PERFORM dblink_send_query( 'hived', 'SELECT public.poll_gate( INTERVAL ''2 seconds'' )' );
    PERFORM pg_sleep( 0.1 );
    __iterations := 0;
    __longest := INTERVAL '0';
    WHILE dblink_is_busy( 'hived' ) = 1 LOOP
        __longest := GREATEST( __longest, public.timed_iteration() );
        __iterations := __iterations + 1;
        PERFORM pg_sleep( 0.05 );
    END LOOP;
    SELECT entered INTO __entered FROM dblink_get_result( 'hived' ) AS t( entered BOOLEAN );
    PERFORM * FROM dblink_get_result( 'hived' ) AS t( entered BOOLEAN );
    INSERT INTO public.results VALUES ( 'polling', __iterations, __longest, __entered );

    -- control: an exclusive request queued for the gate, as pg_advisory_lock makes it
    PERFORM dblink_exec( 'hived', 'SET lock_timeout = ''2s''' );
    PERFORM dblink_send_query( 'hived', 'SELECT pg_advisory_lock( hive.contexts_compaction_gate_key() )::TEXT' );
    PERFORM pg_sleep( 0.3 );
    __longest := public.timed_iteration();
    -- the queued request runs into its lock_timeout
    PERFORM * FROM dblink_get_result( 'hived', FALSE ) AS t( r TEXT );
    PERFORM * FROM dblink_get_result( 'hived', FALSE ) AS t( r TEXT );
    INSERT INTO public.results VALUES ( 'queued', 1, __longest, NULL );

    PERFORM * FROM dblink_get_result( 'long' ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( 'long' ) AS t( status TEXT );
    PERFORM dblink_disconnect( 'long' );
    PERFORM dblink_disconnect( 'other' );
    PERFORM dblink_disconnect( 'hived' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __polling RECORD;
    __queued RECORD;
BEGIN
    SELECT * INTO __polling FROM public.results WHERE phase = 'polling';
    SELECT * INTO __queued FROM public.results WHERE phase = 'queued';
    ASSERT NOT __polling.compactor_entered, 'hived got the gate while the long iteration held it';
    ASSERT __polling.iterations >= 5, format( 'the other application iterated only %s times while hived polled', __polling.iterations );
    ASSERT __polling.longest_iteration < INTERVAL '250 milliseconds',
        format( 'an iteration of the other application took %s while hived polled for the gate', __polling.longest_iteration );
    ASSERT __queued.longest_iteration > INTERVAL '1 second',
        format( 'an iteration behind a queued exclusive request took only %s; the test does not detect queueing', __queued.longest_iteration );
END;
$BODY$
;
