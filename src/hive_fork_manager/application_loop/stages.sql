-- type is used by app_next_block to inform the application
-- about current stage and return batch of blocks

DROP DOMAIN IF EXISTS hive.blocks_count;
CREATE DOMAIN hive.blocks_count AS INTEGER CHECK( VALUE > 0 );

DROP DOMAIN IF EXISTS hive.blocks_distance;
CREATE DOMAIN hive.blocks_distance AS INTEGER CHECK( VALUE >= 0 );

DROP DOMAIN IF EXISTS hive.stage_name;
CREATE DOMAIN hive.stage_name AS TEXT CHECK( VALUE ~ '^[A-Za-z0-9_]+$' );

DROP TYPE IF EXISTS hive.application_stage CASCADE;
CREATE TYPE hive.application_stage AS (
    name hive.stage_name, -- name of the stage
    min_head_block_distance hive.blocks_distance, -- it is a minimum distance to head block for which the stage can be enabled
    blocks_limit_in_group hive.blocks_count -- max number of blocks in one group to process
);

CREATE OR REPLACE FUNCTION hive.live_stage()
    RETURNS hive.application_stage
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN ( 'live', 0, 1 )::hive.application_stage;
END;
$BODY$;


DROP DOMAIN IF EXISTS hive.application_stages;
CREATE DOMAIN hive.application_stages AS hive.application_stage[];

DROP TYPE IF EXISTS hive.application_loop_state;
CREATE TYPE hive.application_loop_state AS (
    -- distance to head block at the moment when stages were analyzed
    -- when the distance the current distance is higher it  means that with
    -- application was stopped for a while or syncing is slow
    -- and stages have to be re-analyzed to update them to new situation
    last_analyze_distance_to_head_block INTEGER,
    -- current stage
    current_stage hive.application_stage,
    -- when iteration of current stage will end
    end_block_range INTEGER, -- sharp condition
    -- how many blocks are processed during one iteration
    size_of_blocks_batch INTEGER,
    -- end block of last batch
    current_batch_end INTEGER --sharp condition
);

