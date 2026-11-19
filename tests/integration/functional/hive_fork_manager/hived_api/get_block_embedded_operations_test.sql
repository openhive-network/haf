
-- hived reports effective operations embedded in other operations (f.e. delegate_rc_operation inside
-- custom_json_operation) as non-virtual operations placed right after their carrier, with the same op_pos;
-- they are not a direct part of the transaction, so get_block has to skip them (unless virtual operations
-- are requested, then all reported operations are returned in the order of reporting)
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    INSERT INTO hafd.transactions
    VALUES
          ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF', NULL )
        , ( 3, 1::SMALLINT, '\xDEED31', 102, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF', NULL )
    ;

    INSERT INTO hafd.operation_types
    VALUES
          ( 0, 'hive::protocol::vote_operation', FALSE )
        , ( 18, 'hive::protocol::custom_json_operation', FALSE )
        , ( 37, 'hive::protocol::delegate_rc_operation', FALSE )
        , ( 72, 'hive::protocol::effective_comment_vote_operation', TRUE )
    ;

    -- inserted out of order on purpose - the order of reporting is in id
    INSERT INTO hafd.operations
    VALUES
        -- id, trx_in_block, op_type_id, op_pos, body
        -- trx 0: vote (with its virtual operation), custom_json with two embedded delegations, vote
          ( hafd.operation_id(3, 4), 0, 37, 2, '{"from":"alice","delegatees":["carol"],"max_rc":2000,"extensions":[]}'::jsonb )
        , ( hafd.operation_id(3, 0), 0, 0, 0, '{"voter":"alice","author":"bob","permlink":"p1","weight":10000}'::jsonb )
        , ( hafd.operation_id(3, 5), 0, 0, 3, '{"voter":"alice","author":"bob","permlink":"p2","weight":10000}'::jsonb )
        , ( hafd.operation_id(3, 2), 0, 18, 2, '{"required_auths":[],"required_posting_auths":["alice"],"id":"rc","json":"[[\"delegate_rc\",{\"from\":\"alice\",\"delegatees\":[\"bob\"],\"max_rc\":1000}],[\"delegate_rc\",{\"from\":\"alice\",\"delegatees\":[\"carol\"],\"max_rc\":2000}]]"}'::jsonb )
        , ( hafd.operation_id(3, 1), 0, 72, 1, '{"voter":"alice","author":"bob","permlink":"p1","weight":0,"rshares":0,"total_vote_weight":0,"pending_payout":{"amount":"0","precision":3,"nai":"@@000000013"}}'::jsonb )
        , ( hafd.operation_id(3, 3), 0, 37, 2, '{"from":"alice","delegatees":["bob"],"max_rc":1000,"extensions":[]}'::jsonb )
        -- trx 1: custom_json with embedded delegation as the only operation
        , ( hafd.operation_id(3, 7), 1, 37, 0, '{"from":"dave","delegatees":["bob"],"max_rc":3000,"extensions":[]}'::jsonb )
        , ( hafd.operation_id(3, 6), 1, 18, 0, '{"required_auths":[],"required_posting_auths":["dave"],"id":"rc","json":"[\"delegate_rc\",{\"from\":\"dave\",\"delegatees\":[\"bob\"],\"max_rc\":3000}]"}'::jsonb )
    ;

    UPDATE hafd.hive_state SET consistent_block = 3;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __vote1 hafd.operation := '{"type":"vote_operation","value":{"voter":"alice","author":"bob","permlink":"p1","weight":10000}}'::jsonb::hafd.operation;
    __vote1_effective hafd.operation := '{"type":"effective_comment_vote_operation","value":{"voter":"alice","author":"bob","permlink":"p1","weight":0,"rshares":0,"total_vote_weight":0,"pending_payout":{"amount":"0","precision":3,"nai":"@@000000013"}}}'::jsonb::hafd.operation;
    __custom_json0 hafd.operation := '{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["alice"],"id":"rc","json":"[[\"delegate_rc\",{\"from\":\"alice\",\"delegatees\":[\"bob\"],\"max_rc\":1000}],[\"delegate_rc\",{\"from\":\"alice\",\"delegatees\":[\"carol\"],\"max_rc\":2000}]]"}}'::jsonb::hafd.operation;
    __delegation_bob hafd.operation := '{"type":"delegate_rc_operation","value":{"from":"alice","delegatees":["bob"],"max_rc":1000,"extensions":[]}}'::jsonb::hafd.operation;
    __delegation_carol hafd.operation := '{"type":"delegate_rc_operation","value":{"from":"alice","delegatees":["carol"],"max_rc":2000,"extensions":[]}}'::jsonb::hafd.operation;
    __vote2 hafd.operation := '{"type":"vote_operation","value":{"voter":"alice","author":"bob","permlink":"p2","weight":10000}}'::jsonb::hafd.operation;
    __custom_json1 hafd.operation := '{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["dave"],"id":"rc","json":"[\"delegate_rc\",{\"from\":\"dave\",\"delegatees\":[\"bob\"],\"max_rc\":3000}]"}}'::jsonb::hafd.operation;
    __delegation_dave hafd.operation := '{"type":"delegate_rc_operation","value":{"from":"dave","delegatees":["bob"],"max_rc":3000,"extensions":[]}}'::jsonb::hafd.operation;
    __block hive.block_type;
BEGIN
    -- operations of the transactions as they were signed
    SELECT * FROM hive.get_block( 3 ) INTO __block;
    RAISE NOTICE 'Transactions array = %', __block.transactions;
    ASSERT array_length( __block.transactions, 1 ) = 2, 'Incorrect number of transactions';
    ASSERT __block.transactions[1].operations = ARRAY[ __vote1, __custom_json0, __vote2 ], 'Incorrect operations of first transaction';
    ASSERT __block.transactions[2].operations = ARRAY[ __custom_json1 ], 'Incorrect operations of second transaction';
    ASSERT __block.transaction_ids = ARRAY[ '\xDEED30'::bytea, '\xDEED31'::bytea ], 'Incorrect transaction_ids array';

    -- all reported operations in the order of reporting
    SELECT * FROM hive.get_block( 3, TRUE ) INTO __block;
    RAISE NOTICE 'Transactions array with virtual operations = %', __block.transactions;
    ASSERT __block.transactions[1].operations = ARRAY[ __vote1, __vote1_effective, __custom_json0, __delegation_bob, __delegation_carol, __vote2 ], 'Incorrect operations of first transaction with virtual operations';
    ASSERT __block.transactions[2].operations = ARRAY[ __custom_json1, __delegation_dave ], 'Incorrect operations of second transaction with virtual operations';

    -- the same through the range variant
    ASSERT ( SELECT (r.transactions[1]).operations FROM hive.get_block_range( 3, 1 ) r ) =ARRAY[ __vote1, __custom_json0, __vote2 ], 'Incorrect operations of first transaction from get_block_range';
END
$BODY$
;
