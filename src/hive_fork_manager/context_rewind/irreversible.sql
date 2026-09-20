CREATE OR REPLACE FUNCTION hive.remove_obsolete_operations( _shadow_table_name TEXT, _irreversible_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    -- A healthy shadow table holds the undo records of a handful of reversible
    -- blocks: a few pages. A file larger than this is left over from a past peak.
    __SHRINK_THRESHOLD_BYTES CONSTANT BIGINT := 1024 * 1024;
    __shadow_table REGCLASS := format( 'hafd.%I', _shadow_table_name )::REGCLASS;
    __is_empty BOOLEAN;
BEGIN
EXECUTE format(
        'DELETE FROM hafd.%I st WHERE st.hive_block_num <= %s'
    , _shadow_table_name
    , _irreversible_block
    );

    -- Self-healing of the shadow table's file size.
    --
    -- The DELETE above has no index to use (shadow tables are keyed by
    -- hive_operation_id only, and a healthy one is too small for an index on
    -- hive_block_num to pay for itself), so it is a sequential scan of the whole
    -- FILE, and it runs for every registered table on every processed block.
    -- VACUUM makes the space of deleted rows reusable but returns pages to the OS
    -- only from an empty tail, and steady per-block inserts keep the tail occupied,
    -- so the file size is a high-water mark of the most rows the table ever held
    -- at once. One bulk write to a registered table while its context is attached
    -- (seen: an application backfilling 69M rows right after switching to forking),
    -- a long-held snapshot blocking vacuum, or a long stretch without irreversible
    -- progress therefore leaves a multi-GB file of empty pages that every
    -- subsequent block scans in full, forever (measured: 6.7 GB, 0.4-1.1 s per
    -- block on mainnet nodes).
    --
    -- So: once the table is empty again, give the file back. The size check is a
    -- stat() and is all a healthy table ever pays. TRUNCATE is transactional, keeps
    -- the hive_operation_id sequence (no RESTART IDENTITY), and only the context
    -- owner's block processor touches a shadow table. Skipped silently when the
    -- caller lacks the privilege, so this can never break block processing.
    IF pg_relation_size( __shadow_table ) <= __SHRINK_THRESHOLD_BYTES THEN
        RETURN;
    END IF;

    IF NOT has_table_privilege( __shadow_table, 'TRUNCATE' ) THEN
        RETURN;
    END IF;

    EXECUTE format( 'SELECT NOT EXISTS( SELECT 1 FROM hafd.%I )', _shadow_table_name ) INTO __is_empty;
    IF __is_empty THEN
        EXECUTE format( 'TRUNCATE hafd.%I', _shadow_table_name );
    END IF;
END;
$BODY$
;
