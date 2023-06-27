DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
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
        ( 1, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.operations
    VALUES
        ( 1, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_5","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hive.operation );

    PERFORM hive.end_massive_sync(5);

    -- live sync
    PERFORM hive.push_block(
                   ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.push_block(
                   ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.set_irreversible( 6 );

    PERFORM hive.push_block(
                   ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    INSERT INTO hive.transactions_reversible
    VALUES
        ( 8, 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 1 )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
        ( 2, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_8_rev","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hive.operation, 1 );


    PERFORM hive.push_block(
                   ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.back_from_fork( 7 );

    PERFORM hive.push_block(
                   ( 8, '\xBADD81', '\xCAFE81', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    INSERT INTO hive.transactions_reversible
    VALUES
        ( 8, 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF', 2 )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
        ( 2, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"account_8","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[]},"memo_key":"STM7tjB4CNqUD5kbTHdrJUaHE76xicHMQdpD5N32a7wTr1qnSmG1V","json_metadata":"{}"}}' :: jsonb :: hive.operation, 2 );

    PERFORM hive.push_block(
                   ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.back_from_fork( 8 );

    PERFORM hive.push_block(
                   ( 9, '\xBADD92', '\xCAFE92', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.push_block(
                   ( 10, '\xBADD1010', '\xCAFE1010', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               , NULL
               );

    PERFORM hive.app_create_context('context');
    PERFORM hive.app_next_block('context'); -- (1,6)
    PERFORM hive.app_context_detach('context');
    PERFORM hive.app_context_detached_save_block_num('context', 6);
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
    PERFORM hive.app_context_attach('context', 6);
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'NULL must be returned since there are no irreversible blocks grater tha 6';
END
$BODY$
;




