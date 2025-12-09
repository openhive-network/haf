-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create blocks 1-2
    PERFORM test.create_blocks(1, 2);

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_next_block( 'context' ); -- move to block 1
    PERFORM hive.app_context_detach( 'context' ); -- back to block 0
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS( SELECT 1 FROM hafd.contexts_log WHERE id = 1 AND context_name = 'context' ), 'No entry for context';
    ASSERT ( SELECT event_type FROM hafd.contexts_log WHERE id = 2 ) = 'DETACHED', 'Wrong context reason != ATTACHED';
    ASSERT ( SELECT application_stage FROM hafd.contexts_log WHERE id = 2 ) IS NULL, 'Wrong context stage != NULL';
    ASSERT ( SELECT application_block FROM hafd.contexts_log WHERE id = 2 ) = 1 , 'Wrong context app block';
    ASSERT ( SELECT application_fork FROM hafd.contexts_log WHERE id = 2 ) = 1 , 'Wrong context app fork';
    ASSERT ( SELECT head_fork_id FROM hafd.contexts_log WHERE id = 2 ) = 1 , 'Wrong context head fork';
    ASSERT ( SELECT head_block FROM hafd.contexts_log WHERE id = 2 ) = 2 , 'Wrong context head block';
END;
$BODY$
;




