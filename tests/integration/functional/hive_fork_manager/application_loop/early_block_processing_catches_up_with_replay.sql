-- hived replays with psql-massive-index-policy=keep-monotonic and its block writer runs ahead of the
-- consistent block. A forking context that opted in with hive.app_context_set_early_block_processing
-- catches up with the consistent block, gets an empty iteration, and resumes when hived commits the next
-- batch. It must only get ranges up to the consistent block, and it must stay detached while hived
-- replays: no ATTACHED event, never left attached between iterations, nothing written to its shadow table.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'early', _schema => 'a', _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 4 ), hafd.live_stage() ] );
    PERFORM hive.app_context_set_early_block_processing( ARRAY[ 'early' ] );

    CREATE TABLE A.processed( block_num INTEGER );
    PERFORM hive.app_register_table( 'a', 'processed', 'early' );

    CREATE TABLE A.iterations( id SERIAL, first_block INTEGER, last_block INTEGER, consistent_block INTEGER, is_attached BOOLEAN );

    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible( 'keep-monotonic' );
    PERFORM hive.set_sync_state( 'REINDEX' );

    -- the block writer has dumped 30 blocks, the other writers only 10 of them
    FOR __block IN 1 .. 30 LOOP
        INSERT INTO hafd.blocks
        VALUES ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp + __block * INTERVAL '3 seconds', 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    END LOOP;
    INSERT INTO hafd.accounts( id, name, block_num ) VALUES ( 5, 'initminer', 1 );
    PERFORM hive.end_massive_sync( 10 );

    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 30 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __consistent_block INTEGER;
    __i INTEGER;
BEGIN
    ASSERT NOT hive.is_instance_ready(), 'deferred indexes are missing, the instance must not be ready';

    FOR __i IN 1 .. 60 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'early' ], __blocks, _wait => FALSE );
        SELECT consistent_block INTO __consistent_block FROM hafd.hive_state;

        INSERT INTO A.iterations( first_block, last_block, consistent_block, is_attached )
        VALUES ( __blocks.first_block, __blocks.last_block, __consistent_block, hive.app_context_is_attached( 'early' ) );

        IF __blocks IS NOT NULL THEN
            INSERT INTO A.processed SELECT generate_series( __blocks.first_block, __blocks.last_block );
        ELSIF ( SELECT current_block_num FROM hafd.contexts WHERE name = 'early' ) >= __consistent_block THEN
            -- caught up with the replay: hived commits its next batch
            EXIT WHEN __consistent_block = 30;
            PERFORM hive.end_massive_sync( __consistent_block + 10 );
        END IF;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range TEXT;
BEGIN
    ASSERT hive.get_sync_state() = 'REINDEX', 'the test must run while hived replays';

    SELECT string_agg( format( '(%s,%s) consistent %s', first_block, last_block, consistent_block ), ', ' ) INTO __range
    FROM A.iterations WHERE last_block > consistent_block;
    ASSERT __range IS NULL, 'ranges past the consistent block were delivered: ' || __range;

    ASSERT ( SELECT COUNT(*) FROM A.iterations WHERE first_block IS NULL ) >= 3, 'the context never caught up with the replay';

    ASSERT ( SELECT array_agg( block_num ORDER BY block_num ) FROM A.processed ) = ( SELECT array_agg( b ) FROM generate_series( 1, 30 ) b )
         , 'blocks 1..30 were not delivered exactly once: ' || ( SELECT array_agg( block_num ORDER BY block_num ) FROM A.processed )::TEXT;

    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'early' ) = 30, 'the context did not reach the consistent block';

    SELECT string_agg( id::TEXT, ', ' ) INTO __range FROM A.iterations WHERE is_attached;
    ASSERT __range IS NULL, 'the context was left attached after iteration(s) ' || __range;

    ASSERT NOT EXISTS ( SELECT 1 FROM hafd.contexts_log WHERE context_name = 'early' AND event_type = 'ATTACHED' )
         , 'the context was attached while hived replays';

    ASSERT ( SELECT COUNT(*) FROM hafd.shadow_a_processed ) = 0, 'block processing wrote to the shadow table, so it ran attached';
END;
$BODY$
;
