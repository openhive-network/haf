-- A forking context kept detached in a massive stage by hive.app_next_iteration, and hived
-- removing processed events from hafd.events_queue, never violate fk_hive_app_context.
-- The application and hived run in their own sessions (dblink), so their transactions overlap
-- as they do in production.
--
-- After a detach the context's events_id is hive.unreachable_event_id(), which does not keep
-- any event in the queue, and its next iteration moves it to the event of the irreversible
-- head. Two races on that move:
-- - app_after_hived: hived is removing that event when the application iterates;
-- - hived_after_app: the application has moved to that event and not committed yet when hived
--   removes events.

CREATE OR REPLACE FUNCTION public.connect_as( _connection TEXT, _user TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    PERFORM dblink_connect( _connection, format( 'host=localhost port=%s dbname=%s user=%s password=test'
        , current_setting( 'port' ), current_database(), _user ) );
    PERFORM dblink_exec( _connection, 'SET lock_timeout = ''10s''' );
END;
$BODY$
;

-- run by hived: pushes blocks _first_block.._block_num, makes them irreversible and moves the head
CREATE OR REPLACE FUNCTION public.hived_makes_irreversible( _first_block INT, _block_num INT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __block INT;
BEGIN
    FOR __block IN _first_block .. _block_num LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL, NULL, NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( _block_num );
    PERFORM test.set_head_block_num( _block_num );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.app_next_iteration_query( _context TEXT )
RETURNS TEXT
LANGUAGE sql
AS
$BODY$
    SELECT format( 'CALL hive.app_next_iteration( ARRAY[ %L ]::hive.contexts_group, NULL, _wait => FALSE )', _context );
$BODY$
;

CREATE OR REPLACE FUNCTION public.record_delivered( _context TEXT, _blocks hive.blocks_range )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    IF _blocks IS NOT NULL THEN
        INSERT INTO public.delivered VALUES( _context, _blocks.first_block, _blocks.last_block );
    END IF;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.app_iterates( _context TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    __blocks := ( SELECT r FROM dblink( 'app', public.app_next_iteration_query( _context ) ) AS t( r hive.blocks_range ) );
    PERFORM public.record_delivered( _context, __blocks );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.app_drains( _context TEXT, _block_num INT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    FOR __iteration IN 1 .. 50 LOOP
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = _context ) >= _block_num;
        PERFORM public.app_iterates( _context );
    END LOOP;
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = _context ) = _block_num
        , format( 'Context %s did not reach block %s', _context, _block_num );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION public.assert_detached_in_massive( _context TEXT )
RETURNS VOID
LANGUAGE plpgsql
AS
$BODY$
BEGIN
    ASSERT hive.get_current_stage_name( _context ) = 'MASSIVE_PROCESSING'
        , format( 'Context %s is in stage %s', _context, hive.get_current_stage_name( _context ) );
    ASSERT NOT hive.app_context_is_attached( _context ), format( 'Context %s is attached', _context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __account hafd.accounts%ROWTYPE := ( 5, 'initminer', 1 );
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE TABLE public.delivered( context TEXT, first_block INTEGER, last_block INTEGER );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();

    PERFORM hive.push_block(
         ( 1, '\xBADD01', '\xCAFE10', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , ARRAY[ __account ]
        , NULL
        , NULL
    );
    PERFORM public.hived_makes_irreversible( 2, 10 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hafd.application_stages := ARRAY[ hive.stage( 'MASSIVE_PROCESSING', 5, 3 ), hafd.live_stage() ];
BEGIN
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name => 'app_after_hived', _schema => 'a', _stages => __context_stages );
    CREATE TABLE a.table1( id INTEGER ) INHERITS( a.app_after_hived );

    CREATE SCHEMA b;
    PERFORM hive.app_create_context( _name => 'hived_after_app', _schema => 'b', _stages => __context_stages );
    CREATE TABLE b.table1( id INTEGER ) INHERITS( b.hived_after_app );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    -- the update variant re-creates hive.get_estimated_hive_head_block() after 'given',
    -- which drops the mock
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 10 );
    COMMIT;

    PERFORM public.connect_as( 'app', 'alice' );
    PERFORM public.connect_as( 'hived', 'test_hived' );

    -- the first analysis of each context selects the massive stage and detaches it
    PERFORM public.app_drains( 'app_after_hived', 10 );
    PERFORM public.app_drains( 'hived_after_app', 10 );
    PERFORM public.assert_detached_in_massive( 'app_after_hived' );
    PERFORM public.assert_detached_in_massive( 'hived_after_app' );

    PERFORM * FROM dblink( 'hived', 'SELECT public.hived_makes_irreversible( 11, 20 )' ) AS t( r TEXT );

    -- hived removes the events of blocks up to 20 and has not committed yet when the
    -- application iterates
    PERFORM dblink_exec( 'hived', 'BEGIN' );
    PERFORM * FROM dblink( 'hived', 'SELECT public.hived_makes_irreversible( 21, 25 )' ) AS t( r TEXT );
    PERFORM dblink_send_query( 'app', public.app_next_iteration_query( 'app_after_hived' ) );
    PERFORM pg_sleep( 0.5 );
    PERFORM dblink_exec( 'hived', 'COMMIT' );
    __blocks := ( SELECT r FROM dblink_get_result( 'app' ) AS t( r hive.blocks_range ) );
    PERFORM * FROM dblink_get_result( 'app' ) AS t( r hive.blocks_range );
    PERFORM public.record_delivered( 'app_after_hived', __blocks );
    PERFORM public.assert_detached_in_massive( 'app_after_hived' );

    -- the remaining context alone decides which events hived keeps
    PERFORM * FROM dblink( 'app', 'SELECT hive.app_remove_context( ''app_after_hived'' )' ) AS t( r TEXT );

    -- the application has not committed its iteration yet when hived removes events
    PERFORM dblink_exec( 'app', 'BEGIN' );
    PERFORM public.app_iterates( 'hived_after_app' );
    PERFORM dblink_send_query( 'hived', 'SELECT public.hived_makes_irreversible( 26, 30 )' );
    PERFORM pg_sleep( 0.5 );
    PERFORM dblink_exec( 'app', 'COMMIT' );
    PERFORM * FROM dblink_get_result( 'hived' ) AS t( r TEXT );
    PERFORM * FROM dblink_get_result( 'hived' ) AS t( r TEXT );
    PERFORM public.assert_detached_in_massive( 'hived_after_app' );

    PERFORM public.app_drains( 'hived_after_app', 30 );
    PERFORM public.assert_detached_in_massive( 'hived_after_app' );

    -- hived removes events while the context is detached between iterations
    PERFORM * FROM dblink( 'hived', 'SELECT public.hived_makes_irreversible( 31, 33 )' ) AS t( r TEXT );
    PERFORM public.app_drains( 'hived_after_app', 33 );
    PERFORM * FROM dblink( 'hived', 'SELECT public.hived_makes_irreversible( 34, 34 )' ) AS t( r TEXT );

    PERFORM dblink_disconnect( 'hived' );
    PERFORM dblink_disconnect( 'app' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __events TEXT[];
    __missing INTEGER;
    __duplicated INTEGER;
BEGIN
    ASSERT EXISTS ( SELECT 1 FROM public.delivered WHERE context = 'app_after_hived' AND first_block = 11 )
        , 'app_after_hived did not get the blocks made irreversible by hived';

    SELECT ARRAY_AGG( log.event_type::TEXT || ':' || COALESCE( log.application_stage::TEXT, '' ) ORDER BY log.id ) INTO __events
    FROM hafd.contexts_log log
    WHERE log.context_name = 'hived_after_app'
      AND log.event_type IN ( 'ATTACHED', 'DETACHED', 'STATE_CHANGED' );
    ASSERT __events = ARRAY[
          'ATTACHED:'
        , 'STATE_CHANGED:MASSIVE_PROCESSING'
        , 'DETACHED:MASSIVE_PROCESSING'
        , 'STATE_CHANGED:live'
        , 'ATTACHED:live'
    ], FORMAT( 'Wrong contexts_log sequence %s', __events );

    SELECT COUNT(*) INTO __missing
    FROM generate_series( 1, 33 ) AS b( num )
    WHERE NOT EXISTS ( SELECT 1 FROM public.delivered d WHERE d.context = 'hived_after_app' AND b.num BETWEEN d.first_block AND d.last_block );
    ASSERT __missing = 0, FORMAT( '%s block(s) were never delivered to the application', __missing );

    SELECT COUNT(*) INTO __duplicated
    FROM generate_series( 1, 33 ) AS b( num )
    WHERE ( SELECT COUNT(*) FROM public.delivered d WHERE d.context = 'hived_after_app' AND b.num BETWEEN d.first_block AND d.last_block ) > 1;
    ASSERT __duplicated = 0, FORMAT( '%s block(s) were delivered more than once', __duplicated );

    ASSERT hive.get_current_stage_name( 'hived_after_app' ) = 'live', 'Context did not reach the live stage';
    ASSERT hive.app_context_is_attached( 'hived_after_app' ), 'Context is not attached';
END;
$BODY$
;
