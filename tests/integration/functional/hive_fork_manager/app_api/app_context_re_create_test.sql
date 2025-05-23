
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE a.table1( id INT ) INHERITS( a.context );

    PERFORM hive.app_remove_context( 'context' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hc.id = hca.context_id WHERE name = 'context' AND current_block_num = 0 AND irreversible_block = 0 AND events_id = 0 AND hca.is_attached = TRUE ), 'No context context';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='blocks_view' ), 'No context blocks view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='transactions_view' ), 'No context transactions view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='operations_view' ), 'No context operations view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='transactions_multisig_view' ), 'No context signatures view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='applied_hardforks_view' ), 'No context applied_hardforks view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name  = 'context' ), 'Context base not table exists';
END;
$BODY$
;





