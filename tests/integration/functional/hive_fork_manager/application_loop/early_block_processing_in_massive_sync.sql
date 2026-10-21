-- hived replays with psql-massive-index-policy=keep-monotonic: the deferred core indexes are missing
-- and the sync state is REINDEX. A context that opted in with hive.app_context_set_early_block_processing
-- processes the irreversible blocks dumped so far; a context that did not waits for the index restore.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'early', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 4 ), hafd.live_stage() ] );
    PERFORM hive.app_create_context( _name => 'late', _schema => 'a', _is_forking => FALSE, _stages => ARRAY[ hive.stage( 'MASSIVE', 5, 4 ), hafd.live_stage() ] );
    PERFORM hive.app_context_set_early_block_processing( ARRAY[ 'early' ] );

    CREATE TABLE A.delivered( first_block INTEGER, last_block INTEGER );

    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.disable_indexes_of_irreversible( 'keep-monotonic' );
    PERFORM hive.set_sync_state( 'REINDEX' );

    -- simulate a massive dump by hived
    FOR __block IN 1 .. 20 LOOP
        INSERT INTO hafd.blocks
        VALUES ( __block, ('\xBADD' || lpad( __block::TEXT, 2, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp + __block * INTERVAL '3 seconds', 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    END LOOP;
    INSERT INTO hafd.accounts( id, name, block_num ) VALUES ( 5, 'initminer', 1 );
    PERFORM hive.end_massive_sync( 20 );

    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 20 );
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
BEGIN
    ASSERT NOT hive.is_instance_ready(), 'deferred indexes are missing, the instance must not be ready';
    ASSERT hive.is_instance_ready_for_block_processing(), 'kept indexes exist, block processing must be possible';

    FOR __i IN 1 .. 3 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'late' ], __blocks, _wait => FALSE );
        ASSERT __blocks IS NULL, 'a context that did not opt in got ' || __blocks::TEXT || ' before the index restore';
    END LOOP;

    FOR __i IN 1 .. 20 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'early' ], __blocks, _wait => FALSE );
        EXIT WHEN __blocks IS NULL AND ( SELECT current_block_num FROM hafd.contexts WHERE name = 'early' ) >= 20;
        IF __blocks IS NOT NULL THEN
            INSERT INTO A.delivered VALUES ( __blocks.first_block, __blocks.last_block );
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
    __missing INTEGER;
BEGIN
    ASSERT hive.get_sync_state() = 'REINDEX', 'the test must run while hived replays';

    SELECT COUNT(*) INTO __missing
    FROM generate_series( 1, 20 ) AS b( num )
    WHERE NOT EXISTS ( SELECT 1 FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block );
    ASSERT __missing = 0, FORMAT( '%s block(s) were never delivered to the opted-in context', __missing );

    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'early' ) = 20, 'the opted-in context did not reach the dumped head';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'late' ) = 0, 'the context that did not opt in processed blocks';

    ASSERT NOT hive.is_instance_ready_for_contexts( ARRAY[ 'early', 'late' ] ), 'a group is early only when all its contexts opted in';
END;
$BODY$
;
