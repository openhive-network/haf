-- Test set_irreversible function - verifies events are properly cleaned
-- Load test utilities
\ir ../test_tools.sql


CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;

    -- Create initial block on fork 0 (irreversible)
    INSERT INTO hafd.blocks(block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
    VALUES ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
         , (6, 'alice', hafd.make_block_id(1, 0))
         , (7, 'bob', hafd.make_block_id(1, 0))
    ;

    PERFORM hive.end_massive_sync( 1 );

    -- Push reversible blocks (push_block uses INTEGER block_num, not block_id)
    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 8, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 1
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 2
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 3
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 4
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __result INT;
BEGIN
    PERFORM hive.set_irreversible( 3 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.events_queue ) = 4, 'Wrong number of events';
    ASSERT ( SELECT hafd.block_id_to_num(hid.consistent_block) FROM hafd.hive_state hid ) = 3 , 'Wrong consistent irreversible block';
    ASSERT EXISTS ( SELECT * FROM hafd.events_queue WHERE event = 'NEW_BLOCK' AND block_num=4 ), 'No NEW_BLOCK event 4';
    ASSERT EXISTS ( SELECT * FROM hafd.events_queue WHERE event = 'NEW_IRREVERSIBLE' AND block_num=3 ), 'No NEW_IRREVERSIBLE event';
END;
$BODY$
;
