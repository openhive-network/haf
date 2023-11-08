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
BEGIN
    PERFORM hive.app_create_context( 'test' );

    WHILE true LOOP
            COMMIT;
            __next_block_range := hive.app_next_block(ARRAY['test']);
            RAISE NOTICE 'App is processing blocks %', __next_block_range;

            IF __next_block_range IS NOT NULL AND __next_block_range.last_block = __last_block THEN
                RAISE NOTICE 'App has already processed all event';
                RETURN;
            END IF;

            IF __next_block_range IS NULL THEN
                CONTINUE;
            END IF;

            IF __next_block_range.last_block - __next_block_range.first_block > __detach_limit THEN
                RAISE NOTICE 'App is detaching and attaching its context';
                CALL hive.appproc_context_detach( ARRAY[ 'test' ] );
                CALL hive.appproc_context_attach( ARRAY[ 'test' ], __next_block_range.last_block );
                CONTINUE;
            END IF;

            IF __next_block_range.last_block % 50 = 0 THEN
                RAISE NOTICE 'App is waiting for bunch of blocks...';
                PERFORM pg_sleep( 1 ); -- wait 1;
                -- because we know the app is used only for test with reindex
                -- all the blocks are irreversible
                -- remove this line when fixing https://gitlab.syncad.com/hive/haf/-/issues/178
                UPDATE hive.contexts SET irreversible_block = get_irreversibe_block();

                RAISE NOTICE 'App ended waiting for bunch of blocks';
            END IF;
        END LOOP;
END
$$
;

CALL test_app_main();
