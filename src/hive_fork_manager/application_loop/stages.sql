-- type is used by app_next_block to inform the application
-- about current stage and return batch of blocks

CREATE DOMAIN hive_data.blocks_count AS INTEGER CHECK( VALUE > 0 );
CREATE DOMAIN hive_data.blocks_distance AS INTEGER CHECK( VALUE >= 0 );
CREATE DOMAIN hive_data.stage_name AS TEXT CHECK( VALUE ~ '^[A-Za-z0-9_]+$' );

CREATE TYPE hive_data.application_stage AS (
    name hive_data.stage_name, -- name of the stage
    min_head_block_distance hive_data.blocks_distance, -- it is a minimum distance to head block for which the stage can be enabled
    blocks_limit_in_group hive_data.blocks_count -- max number of blocks in one group to process
);

CREATE FUNCTION hive_data.live_stage()
    RETURNS hive_data.application_stage
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN ( 'live', 0, 1 )::hive_data.application_stage;
END;
$BODY$;



CREATE DOMAIN hive_data.application_stages AS hive_data.application_stage[];

CREATE TYPE hive_data.application_loop_state AS (
    -- distance to head block at the moment when stages were analyzed
    -- when the distance the current distance is higher it  means that with
    -- application was stopped for a while or syncing is slow
    -- and stages have to be re-analyzed to update them to new situation
    last_analyze_distance_to_head_block INTEGER,
    -- current stage
    current_stage hive_data.application_stage,
    -- when iteration of current stage will end
    end_block_range INTEGER, -- sharp condition
    -- how many blocks are processed during one iteration
    size_of_blocks_batch INTEGER,
    -- end block of last batch
    current_batch_end INTEGER --sharp condition
);

