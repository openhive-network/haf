
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context','a' );

    INSERT INTO hafd.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
    VALUES
           ( hafd.make_block_id(1, 0), '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(2, 0), '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(3, 0), '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(4, 0), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
         , (6, 'alice', hafd.make_block_id(1, 0))
         , (7, 'bob', hafd.make_block_id(1, 0))
    ;

    -- Irreversible transactions (fork_id=0)
    INSERT INTO hafd.transactions
    VALUES
           ( hafd.make_block_id(1, 0), 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(2, 0), 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(3, 0), 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( hafd.make_block_id(4, 0), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
    ;

    -- Irreversible transactions_multisig (fork_id=0)
    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
           ( '\xDEED10', '\xBAAD10', hafd.make_block_id(1, 0) )
         , ( '\xDEED20', '\xBAAD20', hafd.make_block_id(2, 0) )
         , ( '\xDEED30', '\xBAAD30', hafd.make_block_id(3, 0) )
         , ( '\xDEED40', '\xBAAD40', hafd.make_block_id(4, 0) )
    ;

    INSERT INTO hafd.blocks (block_id, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)
    VALUES
           ( hafd.make_block_id(4, 1), '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(5, 1), '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(6, 1), '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(7, 1), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:37-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(10, 1), '\xBADD11', '\xCAFE11', '2016-06-22 19:10:41-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(7, 2), '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 2), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 2), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(8, 3), '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(9, 3), '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( hafd.make_block_id(10, 3), '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    -- Reversible transactions with fork_id encoded in block_id
    INSERT INTO hafd.transactions
    VALUES
       ( hafd.make_block_id(4, 1), 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(5, 1), 0::SMALLINT, '\xDEED55', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(6, 1), 0::SMALLINT, '\xDEED60', 101, 100, '2016-06-22 19:10:26-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(7, 1), 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:37-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(10, 1), 0::SMALLINT, '\xDEED11', 101, 100, '2016-06-22 19:10:41-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(7, 2), 0::SMALLINT, '\xDEED70', 101, 100, '2016-06-22 19:10:27-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(8, 2), 0::SMALLINT, '\xDEED80', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(9, 2), 0::SMALLINT, '\xDEED90', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(8, 3), 0::SMALLINT, '\xDEED88', 101, 100, '2016-06-22 19:10:28-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(9, 3), 0::SMALLINT, '\xDEED99', 101, 100, '2016-06-22 19:10:29-07'::timestamp, '\xBEEF' )
     , ( hafd.make_block_id(10, 3), 0::SMALLINT, '\xDEED1102', 101, 100, '2016-06-22 19:10:30-07'::timestamp, '\xBEEF' )
    ;

    -- Reversible transactions_multisig with fork_id encoded in block_id
    INSERT INTO hafd.transactions_multisig(trx_hash, signature, block_id)
    VALUES
       ( '\xDEED40', '\xBEEF40', hafd.make_block_id(4, 1) )
     , ( '\xDEED55', '\xBEEF55', hafd.make_block_id(5, 1) )
     , ( '\xDEED60', '\xBEEF61', hafd.make_block_id(6, 1) )
     , ( '\xDEED70', '\xBEEF7110', hafd.make_block_id(7, 1) ) --must be abandon because of fork 2
     , ( '\xDEED70', '\xBEEF7120', hafd.make_block_id(7, 1) ) --must be abandon because of fork 2
     , ( '\xDEED70', '\xBEEF7130', hafd.make_block_id(7, 1) ) --must be abandon because of fork 2
     , ( '\xDEED11', '\xBEEF7140', hafd.make_block_id(10, 1) ) --must be abandon because of fork 2
     , ( '\xDEED70', '\xBEEF72', hafd.make_block_id(7, 2) )
     , ( '\xDEED70', '\xBEEF73', hafd.make_block_id(7, 2) )
     , ( '\xDEED80', '\xBEEF82', hafd.make_block_id(8, 2) )
     , ( '\xDEED90', '\xBEEF92', hafd.make_block_id(9, 2) )
     , ( '\xDEED88', '\xBEEF83', hafd.make_block_id(8, 3) )
     , ( '\xDEED99', '\xBEEF93', hafd.make_block_id(9, 3) )
     , ( '\xDEED1102', '\xBEEF13', hafd.make_block_id(10, 3) )
    ;

    UPDATE hafd.contexts SET fork_id = 2, irreversible_block = 4, current_block_num = 4;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_context_detach( 'context' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='a' AND table_name='transactions_multisig_view' ), 'No context transactions multisig view';

    ASSERT NOT EXISTS (
        SELECT * FROM a.transactions_multisig_view
        EXCEPT SELECT * FROM ( VALUES
               ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
             , ( '\xDEED20'::bytea, '\xBAAD20'::bytea )
             , ( '\xDEED30'::bytea, '\xBAAD30'::bytea )
             , ( '\xDEED40'::bytea, '\xBAAD40'::bytea )
         ) as pattern
    ) , 'Unexpected rows in the view';

    ASSERT NOT EXISTS (
        SELECT * FROM ( VALUES
               ( '\xDEED10'::bytea, '\xBAAD10'::bytea )
             , ( '\xDEED20'::bytea, '\xBAAD20'::bytea )
             , ( '\xDEED30'::bytea, '\xBAAD30'::bytea )
             , ( '\xDEED40'::bytea, '\xBAAD40'::bytea )
         ) as pattern
        EXCEPT SELECT * FROM a.transactions_multisig_view
    ) , 'Unexpected rows in the view 2';
END;
$BODY$
;




