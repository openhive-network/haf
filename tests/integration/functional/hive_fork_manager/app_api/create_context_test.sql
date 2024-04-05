CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

    -- check if correct irreversibe block is set
    INSERT INTO hive.blocks VALUES( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 );
    INSERT INTO hive.accounts( id, name, block_num ) VALUES (5, 'initminer', 101);
    PERFORM hive.end_massive_sync( 101 );

    PERFORM hive.app_create_context( 'context2');

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
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'context' AND current_block_num = 0 AND irreversible_block = 0 AND events_id = 0 AND is_attached = TRUE ), 'No context context';
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'context2' AND current_block_num = 0 AND irreversible_block = 101  AND events_id = 0 AND is_attached = TRUE AND schema='hive' ), 'No context context2';
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'context_test' AND current_block_num = 0 AND irreversible_block = 101  AND events_id = 0 AND is_attached = TRUE AND schema='test' ), 'No context context2';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_blocks_view' ), 'No context blocks view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_blocks_view' ), 'No context2 blocks view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_blocks_view' ), 'No context_test blocks view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_transactions_view' ), 'No context transactions view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_transactions_view' ), 'No context2 transactions view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_transactions_view' ), 'No context_test transactions view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_operations_view' ), 'No context operations view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_operations_view' ), 'No context2 operations view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_operations_view' ), 'No context_test operations view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_transactions_multisig_view' ), 'No context signatures view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_transactions_multisig_view' ), 'No context2 signatures view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_transactions_multisig_view' ), 'No context_test signatures view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_context_data_view' ), 'No context context_data_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_context_data_view' ), 'No context2 context_data_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_context_data_view' ), 'No context_test context_data_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_accounts_view' ), 'No context context_accounts_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_accounts_view' ), 'No context2 context_accounts_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_accounts_view' ), 'No context_test context_accounts_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_account_operations_view' ), 'No context context_account_operations_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_account_operations_view' ), 'No context2 context_account_operations_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_account_operations_view' ), 'No context_test context_account_operations_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_applied_hardforks_view' ), 'No context context_applied_hardforks_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_applied_hardforks_view' ), 'No context2 context_applied_hardforks_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_test_applied_hardforks_view' ), 'No context_test context_applied_hardforks_view';
END
$BODY$
;




