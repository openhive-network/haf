-- type is used by app_next_block to inform the application
-- about current stage and return batch of blocks

DROP TYPE IF EXISTS hive.application_stage CASCADE;
CREATE TYPE hive.application_stage AS (
    name TEXT, -- name of the stage
    min_head_block_distance INTEGER, -- it is a minimum distance to head block for which the stage can be enabled
    blocks_limit_in_group INTEGER -- max number of blocks in one group to process
);

