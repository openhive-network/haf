---------------------------- TEST PROVIDER ----------------------------------------------
CREATE OR REPLACE FUNCTION hive.start_provider_tests( _context hive.context_name, _dummy_arg1 TEXT DEFAULT '')
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
__table_1_name TEXT := _context || '_tests1';
__table_2_name TEXT := _context || '_tests2';
BEGIN
    EXECUTE format( 'CREATE TABLE hive.%I(
                          id SERIAL
                        )', __table_1_name
        );

    EXECUTE format( 'CREATE TABLE hive.%I(
                          id SERIAL
                        )', __table_2_name
        );

    RETURN ARRAY[ __table_1_name, __table_2_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_tests( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __table_1_name TEXT := _context || '_tests1';
    __table_2_name TEXT := _context || '_tests2';
BEGIN
    EXECUTE format( 'INSERT INTO hive.%I( id ) VALUES( %L )', __table_1_name,  _first_block + _last_block );
    EXECUTE format( 'INSERT INTO hive.%I( id ) VALUES( %L )', __table_2_name,  _last_block - _first_block );
END;
$BODY$
;

---------------------------END OF TEST PROVIDER -------------------------------------------------------------------

DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    ALTER TYPE hive.state_providers ADD VALUE 'TESTS';

    INSERT INTO hive.operation_types
    VALUES
           ( 1, 'hive::protocol::account_created_operation', TRUE )
         , ( 6, 'other', FALSE ) -- non creating accounts
    ;

    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
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
           ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"from_pow"}}' :: jsonb :: hive.operation ) --pow
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"from_pow2"}}' :: jsonb :: hive.operation ) --pow2
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"create_account"}}' :: jsonb :: hive.operation )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"claimed_account"}}' :: jsonb :: hive.operation )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_created_operation","value":{"initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"claimed_acc_del"}}' :: jsonb :: hive.operation )
         , ( 6, 5, 0, 1, 6, '2016-06-22 19:10:21-07'::timestamp, '{"type":"system_warning_operation","value":{"message":"other"}}' :: jsonb :: hive.operation )
    ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'ACCOUNTS', 'context' );
    PERFORM hive.app_context_detach( 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 6;
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_state_provider_import( 'TESTS', 'context' ); -- TEST must be commited
    PERFORM hive.app_state_providers_update( 1, 6, 'context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.context_accounts ) = 5, 'Wrong number of accounts';

    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'from_pow' ), 'from_pow not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'from_pow2' ), 'from_pow2 not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'create_account' ), 'create_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'claimed_account' ), 'claimed_account not created';
    ASSERT EXISTS ( SELECT * FROM hive.context_accounts WHERE name = 'claimed_acc_del' ), 'account_create_with_delegation_operation not created';

    ASSERT EXISTS ( SELECT * FROM hive.context_tests1 WHERE id = 7 ), 'No id=7 in tests1';
    ASSERT EXISTS ( SELECT * FROM hive.context_tests2 WHERE id = 5 ), 'No id=5 in tests2';
END;
$BODY$
;
