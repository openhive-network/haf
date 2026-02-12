-- =============================================================================
-- Pruning Functions for HAF
-- =============================================================================
-- Updated to work with unified tables using block_id encoding.
-- No FK CASCADE exists, so we must explicitly delete from all child tables.
-- =============================================================================

CREATE OR REPLACE FUNCTION hive.is_pruning_enabled()
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __pruning_is_enabled BOOLEAN := FALSE;
BEGIN
    SELECT COALESCE( pruning > 0, FALSE) INTO __pruning_is_enabled FROM hafd.hive_state;
    RETURN __pruning_is_enabled;
END;
$BODY$;

CREATE OR REPLACE FUNCTION hive.is_lite_mode()
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    STABLE
AS
$BODY$
DECLARE
    __lite_mode BOOLEAN := FALSE;
BEGIN
    SELECT COALESCE( lite_mode, FALSE ) INTO __lite_mode FROM hafd.hive_state;
    RETURN __lite_mode;
END;
$BODY$;


CREATE OR REPLACE FUNCTION hive.prune_blocks_data( _tail_size INTEGER  = 1 )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __upper_bound_block_num INTEGER;
    __max_block_num INTEGER;
BEGIN
    IF _tail_size < 0 THEN
        -- one block at least must stay because of FK hafd.irreversible_data
        RAISE EXCEPTION 'Blocks tail cannot be lower than 0  but is %', _tail_size;
    END IF;

    IF _tail_size = 0 THEN
        RETURN; -- 0 means no pruning
    END IF;

    -- Get max block_num using block_id_to_num
    SELECT MAX(hafd.block_id_to_num(block_id)) INTO __max_block_num FROM hafd.blocks;

    SELECT COALESCE( min(current_block_num), __max_block_num )
    INTO __upper_bound_block_num
    FROM hafd.contexts hc;

    IF __upper_bound_block_num <= _tail_size THEN
        RETURN;
    END IF;

    __upper_bound_block_num = __upper_bound_block_num - _tail_size;

    -- No FK CASCADE exists, so we must explicitly delete from all child tables.
    -- Order matters: delete from child tables before parent tables.

    -- Delete account_operations (references operations)
    DELETE FROM hafd.account_operations ao
    WHERE hafd.block_id_to_num(ao.block_id) <= __upper_bound_block_num;

    -- Delete applied_hardforks (references operations and blocks)
    DELETE FROM hafd.applied_hardforks ah
    WHERE hafd.block_id_to_num(ah.block_id) <= __upper_bound_block_num;

    -- Delete operations
    DELETE FROM hafd.operations o
    WHERE hafd.block_id_to_num(o.block_id) <= __upper_bound_block_num;

    -- Delete transactions_multisig (references transactions)
    DELETE FROM hafd.transactions_multisig tm
    WHERE hafd.block_id_to_num(tm.block_id) <= __upper_bound_block_num;

    -- Delete transactions
    DELETE FROM hafd.transactions t
    WHERE hafd.block_id_to_num(t.block_id) <= __upper_bound_block_num;

    -- Accounts: set block_id to NULL to preserve account names
    -- (accounts may be referenced by other data, we just forget which block created them)
    UPDATE hafd.accounts a
    SET block_id = NULL
    WHERE hafd.block_id_to_num(a.block_id) <= __upper_bound_block_num;

    -- Finally delete blocks
    DELETE FROM hafd.blocks b
    WHERE hafd.block_id_to_num(b.block_id) <= __upper_bound_block_num;

END;
$BODY$
;



CREATE OR REPLACE FUNCTION hive.wait_for_contexts( _tail_size INTEGER  = 1 )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __irreversible_head_block INTEGER;
    __slowest_context_block INTEGER;
    __blocks_before_apps INTEGER;
BEGIN
    IF NOT EXISTS( SELECT current_block_num FROM hafd.contexts ) THEN
        RETURN;
    END IF;

    -- an important finding from tests: application developers need to tailor
    -- block batch size for each stage, slower applications have smaller batch
    -- they cannot process more blocks in one turn, because they will process them for a long time
    -- with a bigger gap between head block and the slowest application gives more data
    -- in the pruned db, what lead to slowdown whole stack.
    -- it is the best to limit the gap to the minimum batch size of contexts
    SELECT COALESCE( MIN( (ctx.loop).size_of_blocks_batch ), _tail_size )
    INTO __blocks_before_apps
    FROM hafd.contexts ctx
    WHERE ctx.stages IS NOT NULL;

    -- Get max block_num using block_id_to_num
    SELECT MAX(hafd.block_id_to_num(block_id)) INTO __irreversible_head_block FROM hafd.blocks;

    FOR i IN 1..1000 LOOP -- after 10s back to close transaction
        SELECT COALESCE( MIN( current_block_num ), 0 ) INTO __slowest_context_block FROM hafd.contexts;

        IF ( __irreversible_head_block <= __slowest_context_block ) THEN
            PERFORM hive.prune_blocks_data( _tail_size );
            RETURN;
        END IF;

       -- HAF is faster than applications
        IF ( __irreversible_head_block  > __slowest_context_block + __blocks_before_apps ) THEN
            PERFORM pg_sleep(0.010);
            CONTINUE;
        END IF;
        PERFORM hive.prune_blocks_data( _tail_size );
        RETURN;
    END LOOP;
    -- the apps are so slow that within 10s they cannot reach head block
    -- anyway we perform prune to clean as much blocks as possible
    PERFORM hive.prune_blocks_data( _tail_size );
END;
$BODY$
;
