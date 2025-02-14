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

    SELECT num INTO __max_block_num FROM hafd.blocks ORDER BY num DESC LIMIT 1;

    SELECT COALESCE( min(current_block_num), __max_block_num )
    INTO __upper_bound_block_num
    FROM hafd.contexts hc;

    IF __upper_bound_block_num <= _tail_size THEN
        RETURN;
    END IF;

    __upper_bound_block_num = __upper_bound_block_num - _tail_size;

    --TODO(mickiewicz@syncad.com): too much times the same schema occur: all hafd blocks tables are modified
    --                   need to add some container to make it automatically (table with oid of hafd tables ?)
    --                   without repeating tables names each time

    DELETE FROM hafd.account_operations har
        USING hafd.operations hor
    WHERE
        har.operation_id = hor.id
      AND ( hafd.operation_id_to_block_num(hor.id) <= __upper_bound_block_num )
    ;

    DELETE FROM hafd.applied_hardforks hjr
    WHERE hjr.block_num <= __upper_bound_block_num
    ;

    DELETE FROM hafd.operations hor
    WHERE hafd.operation_id_to_block_num(hor.id) <= __upper_bound_block_num
    ;

    DELETE FROM hafd.transactions_multisig htmr
        USING hafd.transactions htr
    WHERE
        htr.trx_hash = htmr.trx_hash
      AND ( htr.block_num <= __upper_bound_block_num )
    ;

    DELETE FROM hafd.transactions htr
    WHERE htr.block_num <= __upper_bound_block_num
    ;

    UPDATE hafd.accounts ha
    SET block_num = NULL
    WHERE ha.block_num <= __upper_bound_block_num
    ;

    DELETE FROM hafd.blocks hbr
    WHERE hbr.num <= __upper_bound_block_num
    ;

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

    SELECT num INTO __irreversible_head_block FROM hafd.blocks ORDER BY num DESC LIMIT 1;
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