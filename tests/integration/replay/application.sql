-- This application is used for test when hive is reindexing
-- and the sql-serializer works in LIVE state.
-- The application processes blocks one by one, but
-- after each group of 50 blocks, the application is waiting
-- to allow HAF to sync some number of blocks and then
-- the app will process them in a context detached state.
-- This tests traversing blocks with hive.app_next_block
-- and checks most problematic thing: attaching context while in
-- parallel hived removes unnecessary events.

CREATE OR REPLACE FUNCTION get_irreversibe_block()
    RETURNS INT
    LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __result INT := 1;
BEGIN
    SELECT consistent_block INTO __result FROM hive.irreversible_data;
    RETURN __result;
END
$$
;

CREATE OR REPLACE PROCEDURE test_app_main()
    LANGUAGE 'plpgsql'
AS
$$
DECLARE
    __last_block INT := 1020000;
    __detach_limit INT := 30;
    __next_block_range hive.blocks_range;
    __wait_for_block hive.blocks_range;
    __irreversible_block INT;
    __head_fork_id INT;
    __app_fork_id INT;
    __current_event_id INT;
    __max_reversible_block INT;
    __min_reversible_block INT;
    __context_stages hive.application_stages :=
        ARRAY[
            ('massive',30 ,20000 )::hive.application_stage
            , hive.live_stage()
            ];
BEGIN
    CREATE SCHEMA test;
    PERFORM hive.app_create_context( 'test', 'test', _stages => __context_stages );

    WHILE true LOOP
            CALL hive.app_next_iteration(ARRAY['test'], __next_block_range);
            RAISE NOTICE 'App is processing blocks %', __next_block_range;

            IF __next_block_range IS NOT NULL AND __next_block_range.last_block >= __last_block THEN
                RAISE NOTICE 'App has already processed all event';
                RETURN;
            END IF;

            IF __next_block_range IS NULL THEN
                CONTINUE;
            END IF;

            SELECT irreversible_block INTO __irreversible_block FROM hive.contexts WHERE name = 'test';
            SELECT id INTO __head_fork_id FROM hive.fork ORDER BY id DESC LIMIT 1;
            SELECT fork_id INTO __app_fork_id FROM hive.contexts WHERE name = 'test';
            RAISE NOTICE 'Max fork id %', __head_fork_id;
            RAISE NOTICE 'App fork id %', __app_fork_id;
            RAISE NOTICE 'App current_block_num %', hive.app_get_current_block_num( 'test' );
            RAISE NOTICE 'App irreversible_block_num %', __irreversible_block;
            RAISE NOTICE 'Processing stage %', hive.get_current_stage_name( 'test' );
            RAISE NOTICE 'Processing block %', __next_block_range;
            RAISE NOTICE 'Context is attached %', hive.app_context_is_attached( 'test' );
            SELECT MAX(num), MIN(num) INTO __max_reversible_block, __min_reversible_block FROM hive.blocks_reversible WHERE fork_id = __app_fork_id;
            RAISE NOTICE 'Max reversible block: %', __max_reversible_block;
            RAISE NOTICE 'Min reversible block: %', __min_reversible_block;
            ASSERT EXISTS( SELECT 1 FROM hive.blocks_view WHERE num = __next_block_range.first_block ), 'No data for expected block in HAF HEAD BLOCK view';
            ASSERT EXISTS( SELECT 1 FROM test.blocks_view WHERE num = __next_block_range.first_block ), 'No data for expected block';

            IF __next_block_range.last_block % 50 = 0 THEN
                RAISE NOTICE 'App is waiting for bunch of blocks...';
                PERFORM pg_sleep( 1 ); -- wait 1;
                RAISE NOTICE 'App ended waiting for bunch of blocks';
            END IF;
        END LOOP;
END
$$
;

CALL test_app_main();
