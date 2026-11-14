-- hived's compaction of hafd.contexts, as contexts_compactor runs it, gets its locks while an
-- application iterates and commits every few seconds: polling pg_try_advisory_lock for the gate
-- (hive.contexts_compaction_gate_key) gets it between the iterations, with the gate held exclusively
-- no iteration runs, new ones wait for it, and VACUUM FULL gets its lock within a short lock_timeout.
-- The application and hived run in their own sessions (dblink).
-- Each run must rewrite the table (a new relfilenode); how many dead rows the rewrite reclaims depends
-- on the snapshots of other sessions, which this test does not control.

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

CREATE OR REPLACE FUNCTION public.drain_results( _connection TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM * FROM dblink_get_result( _connection ) AS t( status TEXT );
    PERFORM * FROM dblink_get_result( _connection ) AS t( status TEXT );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.contexts_filenode()
RETURNS OID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    RETURN ( SELECT f FROM dblink( 'hived', 'SELECT pg_relation_filenode( ''hafd.contexts'' )' ) AS t( f OID ) );
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
            RETURN TRUE;
        END IF;
        EXIT WHEN clock_timestamp() >= __deadline;
        PERFORM pg_sleep( 0.05 );
    END LOOP;
    RETURN FALSE;
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
    PERFORM hive.app_create_context( _name => 'iterating', _schema => 'a', _is_forking => TRUE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'starting', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 100, 100 ), hafd.live_stage() ] );
    CREATE TABLE public.results( attempt INTEGER, gate_wait INTERVAL, held_back BOOLEAN, compacted BOOLEAN, error TEXT );

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

    -- dead rows that only a rewrite gives back
    INSERT INTO hafd.contexts( name, schema, current_block_num, irreversible_block, owner, last_active_at, baseclass_id )
    SELECT 'filler_' || i, repeat( 'x', 1000 ), 0, 0, 'compaction_filler', NOW(), 'hafd.contexts'::REGCLASS
    FROM generate_series( 1, 700 ) i;
    DELETE FROM hafd.contexts WHERE owner = 'compaction_filler';
    ASSERT hive.contexts_heap_pages() > 64, format( 'hafd.contexts has only %s pages', hive.contexts_heap_pages() );
    -- leave autovacuum nothing to do on the table, which would make the 100 ms lock_timeout below
    -- a matter of luck; the heap keeps its pages (vacuum_truncate=false)
    COMMIT;
    PERFORM public.connect_as_admin( 'vacuum' );
    PERFORM dblink_exec( 'vacuum', 'VACUUM (ANALYZE) hafd.contexts' );
    PERFORM dblink_disconnect( 'vacuum' );
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
    __attempt INTEGER;
    __starting_pid INTEGER;
    __started_at TIMESTAMPTZ;
    __gate_wait INTERVAL;
    __held_back BOOLEAN;
    __compacted BOOLEAN;
    __error TEXT;
    __filenode OID;
    __entered BOOLEAN;
BEGIN
    FOR __i IN 1 .. 10 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'iterating' ], __blocks, _wait => FALSE );
        EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'iterating' ) = 3;
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'iterating' ) = 3, 'iterating did not reach the head';
    COMMIT;

    PERFORM public.connect_as_admin( 'app' );
    PERFORM public.connect_as_admin( 'starting_app' );
    PERFORM public.connect_as( 'hived', 'test_hived' );
    __starting_pid := public.backend_pid( 'starting_app' );

    -- an eternal loop at the head: each iteration commits and waits up to 4 s for a block
    PERFORM dblink_send_query( 'app',
        'DO $do$ DECLARE __r hive.blocks_range; BEGIN PERFORM pg_current_xact_id(); FOR __i IN 1 .. 4 LOOP CALL hive.app_next_iteration( ARRAY[ ''iterating'' ], __r ); END LOOP; END $do$' );

    FOR __attempt IN 1 .. 3 LOOP
        -- land at a different moment of the loop each time
        PERFORM pg_sleep( 1.3 );
        __held_back := NULL;
        __compacted := FALSE;
        __error := NULL;
        BEGIN
            __started_at := clock_timestamp();
            __entered := ( SELECT entered FROM dblink( 'hived', 'SELECT public.poll_gate( INTERVAL ''5 seconds'' )' ) AS t( entered BOOLEAN ) );
            __gate_wait := clock_timestamp() - __started_at;
            ASSERT __entered, format( 'no gate after %s of polling', __gate_wait );

            -- a starting application is held back until the gate is released
            PERFORM dblink_send_query( 'starting_app', 'CALL hive.app_next_iteration( ARRAY[ ''starting'' ], NULL, _wait => FALSE )' );
            PERFORM pg_sleep( 0.3 );
            __held_back := dblink_is_busy( 'starting_app' ) = 1
                AND EXISTS ( SELECT 1 FROM pg_locks WHERE pid = __starting_pid AND locktype = 'advisory' AND NOT granted );

            __filenode := public.contexts_filenode();
            PERFORM dblink_exec( 'hived', 'SET lock_timeout = ''100ms''' );
            PERFORM dblink_exec( 'hived', 'VACUUM FULL hafd.contexts' );
            __compacted := public.contexts_filenode() != __filenode;
        EXCEPTION WHEN OTHERS THEN
            __error := SQLERRM;
        END;
        PERFORM dblink_exec( 'hived', 'RESET lock_timeout' );
        PERFORM * FROM dblink( 'hived', 'SELECT pg_advisory_unlock_all()' ) AS t( r TEXT );
        PERFORM public.drain_results( 'starting_app' );
        INSERT INTO public.results VALUES ( __attempt, __gate_wait, __held_back, __compacted, __error );
    END LOOP;

    PERFORM public.drain_results( 'app' );
    PERFORM dblink_disconnect( 'app' );
    PERFORM dblink_disconnect( 'starting_app' );
    PERFORM dblink_disconnect( 'hived' );
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
    ASSERT ( SELECT COUNT(*) FROM public.results ) = 3, 'three compactions must have been attempted';
    FOR __row IN SELECT * FROM public.results ORDER BY attempt LOOP
        ASSERT __row.error IS NULL, format( 'attempt %s failed: %s', __row.attempt, __row.error );
        ASSERT __row.compacted, format( 'attempt %s did not rewrite hafd.contexts', __row.attempt );
        ASSERT __row.held_back, format( 'attempt %s: a new iteration was not held back by the gate', __row.attempt );
        ASSERT __row.gate_wait < INTERVAL '1 second', format( 'attempt %s waited %s for the gate', __row.attempt, __row.gate_wait );
    END LOOP;
    -- the application kept iterating
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'iterating' ) = 3, 'iterating lost its position';
END;
$BODY$
;
