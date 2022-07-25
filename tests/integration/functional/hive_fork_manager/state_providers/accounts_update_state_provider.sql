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
          ( 1, 'hive::protocol::account_created_operation', TRUE )
        , ( 6, 'other', FALSE ) -- non creating accounts
    ;

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
     ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
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
           ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ('account_from_pow', 'initminer', NULL, NULL) :: hive.account_created_operation ) --pow
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ('account_from_pow2', 'initminer', NULL, NULL) :: hive.account_created_operation ) --pow2
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ('account_from_create_account', 'initminer', NULL, NULL) :: hive.account_created_operation )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ('account_from_create_claimed_account', 'initminer', NULL, NULL) :: hive.account_created_operation )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, ('account_from_create_claimed_account_del', 'initminer', NULL, NULL) :: hive.account_created_operation )
         , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, ROW('other')::hive.system_warning_operation )
    ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.start_provider_accounts( 'context' );
    UPDATE hive.contexts SET current_block_num = 6, irreversible_block = 6;

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
    PERFORM hive.update_state_provider_accounts( 1, 5, 'context' );
END;
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
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow' ), 'account_from_pow not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_pow2' ), 'account_from_pow2 not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_account' ), 'account_from_create_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account' ), 'account_from_create_claimed_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'account_from_create_claimed_account_del' ), 'account_create_with_delegation_operation not created';

    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts';
END;
$BODY$
;
