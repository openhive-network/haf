DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- GOT PREPARED DATA SCHEMA
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );

    -- check if correct irreversibe block is set
    INSERT INTO hive.blocks VALUES( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' );
    INSERT INTO hive.accounts( id, name, block_num ) VALUES (5, 'initminer', 101);
    PERFORM hive.end_massive_sync( 101 );

    PERFORM hive.app_create_context( 'context2');
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'context' AND current_block_num = 0 AND irreversible_block = 101 AND events_id = 0 AND is_attached = TRUE ), 'No context context';
    ASSERT EXISTS ( SELECT FROM hive.contexts WHERE name = 'context2' AND current_block_num = 0 AND irreversible_block = 101  AND events_id = 0 AND is_attached = TRUE ), 'No context context2';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_blocks_view' ), 'No context blocks view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_blocks_view' ), 'No context2 blocks view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_transactions_view' ), 'No context transactions view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_transactions_view' ), 'No context2 transactions view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_operations_view' ), 'No context operations view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_operations_view' ), 'No context2 operations view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_transactions_multisig_view' ), 'No context signatures view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_transactions_multisig_view' ), 'No context2 signatures view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_context_data_view' ), 'No context context_data_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_context_data_view' ), 'No context2 context_data_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_accounts_view' ), 'No context context_accounts_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_accounts_view' ), 'No context2 context_accounts_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_account_operations_view' ), 'No context context_account_operations_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_account_operations_view' ), 'No context2 context_account_operations_view';

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context_applied_hardforks_view' ), 'No context context_applied_hardforks_view';
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name='context2_applied_hardforks_view' ), 'No context2 context_applied_hardforks_view';

END
$BODY$
;




