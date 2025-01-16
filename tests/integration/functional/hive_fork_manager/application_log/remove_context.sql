
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
        ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 50)
    ;
    PERFORM hive.set_irreversible( 50 );

    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    PERFORM hive.app_next_block( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_remove_context( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
    DECLARE
        _last_entry_id INTEGER;
BEGIN
    SELECT id INTO _last_entry_id
    FROM hafd.contexts_log
    ORDER BY id DESC LIMIT 1;

    ASSERT EXISTS( SELECT 1 FROM hafd.contexts_log WHERE context_name = 'context' ), 'No entry for context';
    ASSERT ( SELECT event_type FROM hafd.contexts_log WHERE id = _last_entry_id ) = 'REMOVED', 'Wrong context reason != REMOVED';
    ASSERT ( SELECT application_stage FROM hafd.contexts_log WHERE id = _last_entry_id ) IS NULL, 'Wrong context stage != NULL';
    ASSERT ( SELECT application_block FROM hafd.contexts_log WHERE id = _last_entry_id ) = 50 , 'Wrong context app block';
    ASSERT ( SELECT application_fork FROM hafd.contexts_log WHERE id = _last_entry_id ) = 1 , 'Wrong context app fork';
    ASSERT ( SELECT head_fork_id FROM hafd.contexts_log WHERE id = _last_entry_id ) = 1 , 'Wrong context head fork';
    ASSERT ( SELECT head_block FROM hafd.contexts_log WHERE id = _last_entry_id ) = 50 , 'Wrong context head block';
END;
$BODY$
;





