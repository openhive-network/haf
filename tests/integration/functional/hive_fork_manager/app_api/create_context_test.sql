CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;

    PERFORM hive.app_create_context(  _name =>'context', _schema => 'a' );

    -- check if correct irreversibe block is set
    INSERT INTO hafd.blocks VALUES( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    INSERT INTO hafd.accounts( id, name, block_num ) VALUES (5, 'initminer', 101);
    PERFORM hive.end_massive_sync( 101 );

    PERFORM hive.app_create_context( _name => 'context2', _schema => 'b' );

    CREATE SCHEMA test;
    PERFORM hive.app_create_context( _name=>'context_test', _schema=>'test');
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hc.id = hca.context_id WHERE name = 'context' AND current_block_num = 0 AND irreversible_block = 0 AND events_id = 0 AND hca.is_attached = TRUE ), 'No context context';
    ASSERT EXISTS ( SELECT FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hc.id = hca.context_id WHERE name = 'context2' AND current_block_num = 0 AND irreversible_block = 101  AND events_id = 0 AND hca.is_attached = TRUE AND schema='b' ), 'No context context2';
    ASSERT EXISTS ( SELECT FROM hafd.contexts hc JOIN hafd.contexts_attachment hca ON hc.id = hca.context_id WHERE name = 'context_test' AND current_block_num = 0 AND irreversible_block = 101  AND events_id = 0 AND hca.is_attached = TRUE AND schema='test' ), 'No context test';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='blocks_view' ), 'No context blocks view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='blocks_view' ), 'No context2 blocks view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='blocks_view' ), 'No context_test blocks view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='transactions_view' ), 'No context transactions view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='transactions_view' ), 'No context2 transactions view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='transactions_view' ), 'No context_test transactions view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='operations_view' ), 'No context operations view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='operations_view' ), 'No context2 operations view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='operations_view' ), 'No context_test operations view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='transactions_multisig_view' ), 'No context signatures view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='transactions_multisig_view' ), 'No context2 signatures view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='transactions_multisig_view' ), 'No context_test signatures view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='context_data_view' ), 'No context context_data_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='context_data_view' ), 'No context2 context_data_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='context_data_view' ), 'No context_test context_data_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='accounts_view' ), 'No context context_accounts_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='accounts_view' ), 'No context2 context_accounts_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='accounts_view' ), 'No context_test context_accounts_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='account_operations_view' ), 'No context context_account_operations_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='account_operations_view' ), 'No context2 context_account_operations_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='account_operations_view' ), 'No context_test context_account_operations_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='applied_hardforks_view' ), 'No context context_applied_hardforks_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='b' AND table_name='applied_hardforks_view' ), 'No context2 context_applied_hardforks_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='test' AND table_name='applied_hardforks_view' ), 'No context_test context_applied_hardforks_view';
END
$BODY$
;




