DROP FUNCTION IF EXISTS test_hived_test_given;
CREATE FUNCTION test_hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
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
    PERFORM hive.end_massive_sync(5);

    INSERT INTO hive.hived_connections
    VALUES( 1, 1 , 'SHA', now() );
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_then;
CREATE FUNCTION alice_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    BEGIN
        DELETE FROM hive.blocks;
        ASSERT FALSE, 'Alice can delete irreversible blocks';
    EXCEPTION WHEN OTHERS THEN
    END;

BEGIN
    DELETE FROM hive.transactions_multisig;
        ASSERT FALSE, 'Alice can delete irreversible transactions_multisig';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.transactions;
        ASSERT FALSE, 'Alice can delete irreversible transactions';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.operation_types;
        ASSERT FALSE, 'Alice can delete irreversible operation_types';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.operations;
        ASSERT FALSE, 'Alice can delete irreversible operations';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.fork;
        ASSERT FALSE, 'Alice can delete hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        INSERT INTO hive.fork VALUES( 1, 15, now() );
        ASSERT FALSE, 'Alice can insert to hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hive.fork SET num = 10;
        ASSERT FALSE, 'Alice can update to hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP TABLE hive.fork;
        ASSERT FALSE, 'Alice can drop hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.events_queue;
        ASSERT FALSE, 'Alice can delete hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        INSERT INTO hive.events_queue VALUES( 1, 'MASSIVE_SYNC', 10 );
        ASSERT FALSE, 'Alice can insert to hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hive.events_queue SET event = 'MASSIVE_SYNC';
        ASSERT FALSE, 'Alice can update to hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP TABLE hive.events_queue;
        ASSERT FALSE, 'Alice can drop hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
       DELETE FROM hive.hived_connections;
       ASSERT FALSE, 'Alice can delete from hive.hived_connections';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        INSERT INTO hive.hived_connections VALUES( 2,2, 'SHA', now() );
        ASSERT FALSE, 'Alice can insert to hive.hived_connections';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hive.hived_connections SET git_sha = 'SHA2';
        ASSERT FALSE, 'Alice can update hive.hived_connections';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP TABLE hive.hived_connections;
        ASSERT FALSE, 'Alice can drop hive.hived_connections';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.accounts;
        ASSERT FALSE, 'Alice can delete irreversible accounts';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.account_operations;
        ASSERT FALSE, 'Alice can delete irreversible account_operations';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW hive.blocks_view;
        ASSERT FALSE, 'Alice can drop hive.blocks_view';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW hive.transactions_view;
        ASSERT FALSE, 'Alice can drop transactions_view';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW hive.transactions_multisig_view;
        ASSERT FALSE, 'Alice can drop hive.transactions_multisig_view';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW hive.operations_view;
        ASSERT FALSE, 'Alice can drop hive.operations_view';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
    DROP VIEW hive.accounts_view;
        ASSERT FALSE, 'Alice can drop hive.accounts_view';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP VIEW hive.account_operations_view;
        ASSERT FALSE, 'Alice can drop hive.account_operations_view';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.set_irreversible_dirty();
        ASSERT FALSE, 'Alice can call hive.set_irreversible_dirty';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        PERFORM hive.set_irreversible_not_dirty();
        ASSERT FALSE, 'Alice can call hive.set_irreversible_not_dirty';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;
