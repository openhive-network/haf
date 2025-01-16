
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
    ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hafd.fork VALUES( 2, 2, '2016-06-22 19:10:24-07'::timestamp );
    INSERT INTO hafd.fork VALUES( 3, 3, '2016-06-22 19:10:25-07'::timestamp );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a', _is_attached => False  );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_set_current_block_num( 'context', 2 );
    CALL hive.appproc_context_attach( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS( SELECT 1 FROM hafd.contexts_log WHERE id = 1 AND context_name = 'context' ), 'No entry for context';
    ASSERT ( SELECT event_type FROM hafd.contexts_log WHERE id = 2 ) = 'ATTACHED', 'Wrong context reason != ATTACHED';
    ASSERT ( SELECT application_stage FROM hafd.contexts_log WHERE id = 2 ) IS NULL, 'Wrong context stage != NULL';
    ASSERT ( SELECT application_block FROM hafd.contexts_log WHERE id = 2 ) = 2 , 'Wrong context app block';
    ASSERT ( SELECT application_fork FROM hafd.contexts_log WHERE id = 2 ) = 2 , 'Wrong context app fork';
    ASSERT ( SELECT head_fork_id FROM hafd.contexts_log WHERE id = 2 ) = 3 , 'Wrong context head fork';
    ASSERT ( SELECT head_block FROM hafd.contexts_log WHERE id = 2 ) = 3 , 'Wrong context head block';
END;
$BODY$
;


