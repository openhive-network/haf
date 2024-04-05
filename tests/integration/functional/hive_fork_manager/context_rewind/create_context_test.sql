CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'my_context' );
    PERFORM hive.context_create( 'my_context2' );

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
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'my_context' AND current_block_num = 0 AND irreversible_block = 0 AND is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'my_context2' AND current_block_num = 0 AND irreversible_block = 0 AND is_attached = TRUE );
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'my_contextapp' AND current_block_num = 0 AND irreversible_block = 0 AND is_attached = TRUE );

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='myapp' AND table_name  = 'my_contextapp' ), 'Context table in schema myapp does not exist';
END
$BODY$
;




