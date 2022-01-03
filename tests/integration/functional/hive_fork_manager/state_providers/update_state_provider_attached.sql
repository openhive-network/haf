DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES
           ( 1, 'hive::protocol::account_created_operation', FALSE )
         , ( 6, 'other', FALSE ) -- non creating accounts
    ;

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
    ;

    INSERT INTO hive.transactions
    VALUES
           ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.operations
    VALUES
           ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_pow"}}' ) --pow
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_pow2"}}' ) --pow2
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_create_account"}}' )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_create_claimed_account"}}' )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"value":{"new_account_name": "account_from_create_claimed_account_del"}}' )
         , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, 'other' )
    ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 6;
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
    --
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_state_providers_update( 1, 1, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 1, 'Wrong number of accounts 1';
    RETURN;
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow' ), 'account_from_pow not created';

    PERFORM hive.app_next_block( 'context' ); -- 2
    PERFORM hive.app_state_providers_update( 2, 2, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 2, 'Wrong number of accounts 2';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow2' ), 'account_from_pow2 not created';

    PERFORM hive.app_next_block( 'context' ); -- 3
    PERFORM hive.app_state_providers_update( 3, 3, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 3, 'Wrong number of accounts 3';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_account' ), 'account_from_create_account not created';

    PERFORM hive.app_next_block( 'context' ); -- 4
    PERFORM hive.app_state_providers_update( 4, 4, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 4, 'Wrong number of accounts 4';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account' ), 'account_from_create_claimed_account not created';

    PERFORM hive.app_next_block( 'context' ); -- 5
    PERFORM hive.app_state_providers_update( 5, 5, 'context' );
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts 5';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account_del' ), 'account_create_with_delegation_operation not created';

    PERFORM hive.app_next_block( 'context' ); -- 6
    PERFORM hive.app_state_providers_update( 6, 6, 'context' );

    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts';
END;
$BODY$
;
