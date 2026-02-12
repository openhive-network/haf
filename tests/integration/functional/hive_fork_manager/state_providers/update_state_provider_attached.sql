-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES
           ( 1, 'hive::protocol::account_created_operation', FALSE )
         , ( 6, 'other', FALSE ) -- non creating accounts
    ;

    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
    ;

    INSERT INTO hafd.transactions
    VALUES
           ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(4, 0), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(5, 0), 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hafd.operations(block_id, trx_in_block, op_type_id, op_pos, body_binary, id)
    VALUES
           ( hafd.make_block_id(1, 0), 0, 1, 0, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"from_pow"}}' :: jsonb :: hafd.operation, hafd.operation_id(1, 1) ) --pow
         , ( hafd.make_block_id(2, 0), 0, 1, 0, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"from_pow2"}}' :: jsonb :: hafd.operation, hafd.operation_id(2, 1) ) --pow2
         , ( hafd.make_block_id(3, 0), 0, 1, 0, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"create_account"}}' :: jsonb :: hafd.operation, hafd.operation_id(3, 1) )
         , ( hafd.make_block_id(4, 0), 0, 1, 0, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"claimed_account"}}' :: jsonb :: hafd.operation, hafd.operation_id(4, 1) )
         , ( hafd.make_block_id(5, 0), 0, 1, 0, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"claimed_acc_del"}}' :: jsonb :: hafd.operation, hafd.operation_id(5, 1) )
         , ( hafd.make_block_id(4, 0), 0, 6, 1, '{"type":"system_warning_operation","value":{"message":"other"}}' :: jsonb :: hafd.operation, hafd.operation_id(4, 6) )
    ;

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );

    UPDATE hafd.contexts SET current_block_num = 1, irreversible_block = 6;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_state_providers_update( 1, 1, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hafd.context_accounts ) = 1, 'Wrong number of accounts 1';

    ASSERT EXISTS ( SELECT * FROM hafd.context_accounts WHERE name = 'from_pow' ), 'from_pow not created';

    PERFORM hive.app_next_block( 'context' ); -- 2
    PERFORM hive.app_state_providers_update( 2, 2, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hafd.context_accounts ) = 2, 'Wrong number of accounts 2';
    ASSERT EXISTS ( SELECT * FROM hafd.context_accounts WHERE name = 'from_pow2' ), 'from_pow2 not created';

    PERFORM hive.app_next_block( 'context' ); -- 3
    PERFORM hive.app_state_providers_update( 3, 3, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hafd.context_accounts ) = 3, 'Wrong number of accounts 3';
    ASSERT EXISTS ( SELECT * FROM hafd.context_accounts WHERE name = 'create_account' ), 'create_account not created';

    PERFORM hive.app_next_block( 'context' ); -- 4
    PERFORM hive.app_state_providers_update( 4, 4, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hafd.context_accounts ) = 4, 'Wrong number of accounts 4';
    ASSERT EXISTS ( SELECT * FROM hafd.context_accounts WHERE name = 'claimed_account' ), 'claimed_account not created';

    PERFORM hive.app_next_block( 'context' ); -- 5
    PERFORM hive.app_state_providers_update( 5, 5, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hafd.context_accounts ) = 5, 'Wrong number of accounts 5';
    ASSERT EXISTS ( SELECT * FROM hafd.context_accounts WHERE name = 'claimed_acc_del' ), 'account_create_with_delegation_operation not created';

    PERFORM hive.app_next_block( 'context' ); -- 6
    PERFORM hive.app_state_providers_update( 6, 6, 'context' );

    ASSERT ( SELECT COUNT(*) FROM hafd.context_accounts ) = 5, 'Wrong number of accounts';
END;
$BODY$
;
