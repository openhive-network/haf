CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'my_context', 'a' );
    PERFORM hive.context_create( 'my_context2', 'a' );

    CREATE SCHEMA myapp;
    PERFORM hive.context_create( _name => 'my_contextapp', _schema => 'myapp' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hc.id = hca.context_id WHERE name = 'my_context' AND current_block_num = 0 AND irreversible_block = 0 AND hca.is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hc.id = hca.context_id WHERE name = 'my_context2' AND current_block_num = 0 AND irreversible_block = 0 AND hca.is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.contexts hc JOIN hive.contexts_attachment hca ON hc.id = hca.context_id WHERE name = 'my_contextapp' AND current_block_num = 0 AND irreversible_block = 0 AND hca.is_attached = TRUE );

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='myapp' AND table_name  = 'my_contextapp' ), 'Context table in schema myapp does not exist';
END
$BODY$
;




