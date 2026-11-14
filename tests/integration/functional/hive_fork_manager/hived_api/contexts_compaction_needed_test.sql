-- hived compacts hafd.contexts only while it is live, never during a replay or a massive sync, and
-- only once the heap has outgrown the threshold.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- dead rows that only a rewrite gives back
    INSERT INTO hafd.contexts( name, schema, current_block_num, irreversible_block, owner, last_active_at, baseclass_id )
    SELECT 'filler_' || i, repeat( 'x', 1000 ), 0, 0, 'compaction_filler', NOW(), 'hafd.contexts'::REGCLASS
    FROM generate_series( 1, 700 ) i;
    DELETE FROM hafd.contexts WHERE owner = 'compaction_filler';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __state hafd.sync_state;
    __pages BIGINT := hive.contexts_heap_pages();
BEGIN
    ASSERT __pages > 64, format( 'hafd.contexts has only %s pages', __pages );

    FOREACH __state IN ARRAY ARRAY[ 'START', 'WAIT', 'REINDEX_WAIT', 'REINDEX', 'P2P' ]::hafd.sync_state[] LOOP
        PERFORM hive.set_sync_state( __state );
        ASSERT NOT hive.is_contexts_compaction_needed( 64 ), format( 'compaction requested in state %s', __state );
    END LOOP;

    PERFORM hive.set_sync_state( 'LIVE' );
    ASSERT hive.is_contexts_compaction_needed( 64 ), format( 'no compaction requested for %s pages while live', __pages );
    ASSERT NOT hive.is_contexts_compaction_needed( __pages ), 'compaction requested for a heap at the threshold';
END;
$BODY$
;
