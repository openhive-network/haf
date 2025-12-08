-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE test_hived_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- Create blocks 1-5
    PERFORM test.create_blocks(1, 5);

    -- Create initminer account
    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;
    PERFORM hive.end_massive_sync(5);

    INSERT INTO hafd.hived_connections
    VALUES( 1, 1 , 'SHA', now() );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    BEGIN
        DELETE FROM hafd.blocks;
        ASSERT FALSE, 'Alice can delete irreversible blocks';
    EXCEPTION WHEN OTHERS THEN
    END;

BEGIN
    DELETE FROM hafd.transactions_multisig;
        ASSERT FALSE, 'Alice can delete irreversible transactions_multisig';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hafd.transactions;
        ASSERT FALSE, 'Alice can delete irreversible transactions';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hafd.operation_types;
        ASSERT FALSE, 'Alice can delete irreversible operation_types';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hafd.operations;
        ASSERT FALSE, 'Alice can delete irreversible operations';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hafd.fork;
        ASSERT FALSE, 'Alice can delete hafd.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        INSERT INTO hafd.fork VALUES( 1, 15, now() );
        ASSERT FALSE, 'Alice can insert to hafd.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hafd.fork SET num = 10;
        ASSERT FALSE, 'Alice can update to hafd.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP TABLE hafd.fork;
        ASSERT FALSE, 'Alice can drop hafd.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hafd.events_queue;
        ASSERT FALSE, 'Alice can delete from hafd.events_queue';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        INSERT INTO hafd.events_queue VALUES( 1, 1, 'NEW_BLOCK', now() );
        ASSERT FALSE, 'Alice can insert to hafd.events_queue';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hafd.events_queue SET event = 'NEW_IRREVERSIBLE';
        ASSERT FALSE, 'Alice can update to hafd.events_queue';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP TABLE hafd.events_queue;
        ASSERT FALSE, 'Alice can drop hafd.events_queue';
    EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;
