
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __fork_id INT;
    __context_stages hafd.application_stages := ARRAY[ hive.stage('stage1',1 ,100 ), hafd.live_stage() ];
BEGIN
    SELECT MAX(hf.id) INTO __fork_id FROM hafd.fork hf;

    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hafd.blocks
    VALUES (2, '\xBADD12', '\xCAFE12', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hafd.blocks
    VALUES (3, '\xBADD13', '\xCAFE13', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    UPDATE hafd.hive_state SET consistent_block = 3;

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a', _stages => __context_stages  );

    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __fork_id INT;
BEGIN
    INSERT INTO hafd.fork(block_num, time_of_fork)
    VALUES( 3, LOCALTIMESTAMP );
    SELECT MAX(hf.id) INTO __fork_id FROM hafd.fork hf;

    INSERT INTO hafd.events_queue( event, block_num )
    VALUES
        ( 'BACK_FROM_FORK', __fork_id ),
        ( 'NEW_BLOCK', 4)
    ;
    SELECT fork_id INTO __fork_id FROM hafd.contexts WHERE name = 'context';
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
    __blocks hive.blocks_range;
    __irreversible_block INT;
BEGIN
    SELECT fork_id INTO __context_fork_id FROM hafd.contexts WHERE name = 'context'; --(1,3)
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    SELECT irreversible_block INTO  __irreversible_block FROM hafd.contexts WHERE name = 'context';
    RAISE NOTICE 'Blocks: % ir % fork %', __blocks, __irreversible_block, __context_fork_id;
    ASSERT __blocks = (1,3), 'Wrong range of blocks !=(1,3)';
    ASSERT hive.app_context_is_attached( 'context' ) = FALSE, 'Context context is attached';

    SELECT fork_id INTO __context_fork_id FROM hafd.contexts WHERE name = 'context';
    SELECT MAX(hf.id) INTO __recent_fork_id FROM hafd.fork hf;

    ASSERT __context_fork_id = __recent_fork_id, 'Context has invalid fork id';

    RAISE NOTICE 'Current block: %', hive.app_get_current_block_num( 'context' );
    ASSERT hive.app_get_current_block_num( 'context' ) = 3, 'Wrong current block num';
END
$BODY$
;




