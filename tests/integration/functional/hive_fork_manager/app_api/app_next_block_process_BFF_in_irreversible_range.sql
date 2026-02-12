-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __fork_id INT;
BEGIN
    SELECT MAX(hf.id) INTO __fork_id FROM hafd.fork hf;

    -- Create blocks 1-3
    PERFORM test.create_blocks(1, 3);

    -- Create initminer account
    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0));

    UPDATE hafd.hive_state SET consistent_block = hafd.make_block_id(3, 0);

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
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
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    SELECT irreversible_block INTO  __irreversible_block FROM hafd.contexts WHERE name = 'context';
    RAISE NOTICE 'Blocks: % ir % fork %', __blocks, __irreversible_block, __context_fork_id;
    ASSERT __blocks = (1,3), 'Wrong range of blocks !=(1,3)';

    SELECT fork_id INTO __context_fork_id FROM hafd.contexts WHERE name = 'context';
    SELECT MAX(hf.id) INTO __recent_fork_id FROM hafd.fork hf;

    ASSERT __context_fork_id = __recent_fork_id, 'Context has invalid fork id';

    RAISE NOTICE 'Current block: %', hive.app_get_current_block_num( 'context' );
    ASSERT hive.app_get_current_block_num( 'context' ) = 1, 'Wrong current block num';
END
$BODY$
;




