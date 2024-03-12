
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __fork_id INT;
BEGIN
    SELECT MAX(hf.id) INTO __fork_id FROM hive.fork hf;
    INSERT INTO hive.events_queue( event, block_num )
    VALUES
        ( 'NEW_BLOCK', 1),
        ( 'NEW_BLOCK', 2),
        ( 'NEW_IRREVERSIBLE', 1),
        ( 'NEW_BLOCK', 3),
        ( 'NEW_IRREVERSIBLE', 2),
        ( 'NEW_IRREVERSIBLE', 3)
    ;
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hive.blocks
    VALUES (2, '\xBADD12', '\xCAFE12', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hive.blocks
    VALUES (3, '\xBADD13', '\xCAFE13', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    UPDATE hive.irreversible_data SET consistent_block = 3;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_create_context( 'context2' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __irreversible_block INT;
    __fork_id INT;
BEGIN
    -- theoretically next_block should process NEW_BLOCK 3, but optimizations for fork
    -- will ommit unnecessary events which will be rewinded, and we get BFF EVENT 2
    SELECT * FROM hive.app_next_block( ARRAY[ 'context', 'context2' ] ) INTO __blocks;
    SELECT irreversible_block INTO  __irreversible_block FROM hive.contexts WHERE name = 'context';
    RAISE NOTICE 'Blocks: % ir %', __blocks, __irreversible_block;
    SELECT * FROM hive.app_next_block( ARRAY[ 'context', 'context2' ] ) INTO __blocks;
    SELECT irreversible_block INTO  __irreversible_block FROM hive.contexts WHERE name = 'context';
    RAISE NOTICE 'Blocks: % ir %', __blocks, __irreversible_block;
    SELECT * FROM hive.app_next_block( ARRAY[ 'context', 'context2' ] ) INTO __blocks;
    SELECT fork_id INTO __fork_id FROM hive.contexts WHERE name = 'context';
    SELECT irreversible_block INTO  __irreversible_block FROM hive.contexts WHERE name = 'context';
    RAISE NOTICE 'Blocks: % ir % fork %', __blocks, __irreversible_block, __fork_id;

    INSERT INTO hive.fork(block_num, time_of_fork)
    VALUES( 3, LOCALTIMESTAMP );
    SELECT MAX(hf.id) INTO __fork_id FROM hive.fork hf;

    INSERT INTO hive.events_queue( event, block_num )
    VALUES
        ( 'BACK_FROM_FORK', __fork_id ),
        ( 'NEW_BLOCK', 4)
    ;
    SELECT fork_id INTO __fork_id FROM hive.contexts WHERE name = 'context';
    SELECT * FROM hive.app_next_block( ARRAY[ 'context', 'context2' ] ) INTO __blocks;
    SELECT irreversible_block INTO  __irreversible_block FROM hive.contexts WHERE name = 'context';
    RAISE NOTICE 'Blocks: % ir % fork %', __blocks, __irreversible_block, __fork_id;

    SELECT fork_id INTO __fork_id FROM hive.contexts WHERE name = 'context';
    SELECT * FROM hive.app_next_block( ARRAY[ 'context', 'context2' ] ) INTO __blocks;
    SELECT irreversible_block INTO  __irreversible_block FROM hive.contexts WHERE name = 'context';
    RAISE NOTICE 'Blocks: % ir % fork %', __blocks, __irreversible_block, __fork_id;

END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_fork_id INT;
    __recent_fork_id INT;
BEGIN
    SELECT fork_id INTO __context_fork_id FROM hive.contexts WHERE name = 'context';
    SELECT MAX(hf.id) INTO __recent_fork_id FROM hive.fork hf;

    ASSERT __context_fork_id = __recent_fork_id, 'Context has invalid fork id';

    SELECT fork_id INTO __context_fork_id FROM hive.contexts WHERE name = 'context2';

    ASSERT __context_fork_id = __recent_fork_id, 'Context2 has invalid fork id';
END
$BODY$
;




