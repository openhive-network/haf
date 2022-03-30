DROP FUNCTION IF EXISTS hived_test_given;
CREATE FUNCTION hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES ( 0, 'OP 0', FALSE )
         , ( 1, 'OP 1', FALSE )
         , ( 2, 'OP 2', FALSE )
         , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hive.fork( id, block_num, time_of_fork)
    VALUES ( 2, 6, '2020-06-22 19:10:25-07'::timestamp ),
           ( 3, 7, '2020-06-22 19:10:25-07'::timestamp );

    INSERT INTO hive.blocks
    VALUES
    ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
    ;

    INSERT INTO hive.blocks_reversible
    VALUES
    ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 1 )
         , ( 5, '\xBADD5A', '\xCAFE5A', '2016-06-22 19:10:55-07'::timestamp, 1 )
         , ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:26-07'::timestamp, 1 )
         , ( 7, '\xBADD7001', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 1 ) -- must be overriden by fork 2
         , ( 8, '\xBADD8001', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 1 ) -- must be overriden by fork 2
         , ( 9, '\xBADD9001', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 1 ) -- must be overriden by fork 2
         , ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:27-07'::timestamp, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:28-07'::timestamp, 2 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:29-07'::timestamp, 2 )
         , ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:30-07'::timestamp, 3 )
         , ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:31-07'::timestamp, 3 )
         , ( 10, '\xBADD1A', '\xCAFE1A', '2016-06-22 19:10:32-07'::timestamp, 3 )
    ;

    INSERT INTO hive.transactions
    VALUES
    ( 1, 0::SMALLINT, '\xDEED10', 101, 100, '2016-06-22 19:10:21-07'::timestamp, '\xBEEF' )
         , ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:22-07'::timestamp, '\xBEEF' )
         , ( 3, 0::SMALLINT, '\xDEED30', 101, 100, '2016-06-22 19:10:23-07'::timestamp, '\xBEEF' )
         , ( 4, 0::SMALLINT, '\xDEED40', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF' )
         , ( 5, 0::SMALLINT, '\xDEED50', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' )
    ;

    INSERT INTO hive.transactions_multisig
    VALUES
    ( '\xDEED10', '\xBAAD10' )
         , ( '\xDEED20', '\xBAAD20' )
         , ( '\xDEED30', '\xBAAD30' )
         , ( '\xDEED40', '\xBAAD40' )
         , ( '\xDEED50', '\xBAAD50' )
    ;

    INSERT INTO hive.operations
    VALUES
    ( 1, 1, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ZERO OPERATION' )
         , ( 2, 2, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ONE OPERATION' )
         , ( 3, 3, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'TWO OPERATION' )
         , ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'THREE OPERATION' )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'FIVE OPERATION' )
    ;

    INSERT INTO hive.operations_reversible
    VALUES
    ( 4, 4, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'THREE OPERATION', 1 )
         , ( 5, 5, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'FIVEFIVE OPERATION', 1 )
         , ( 6, 6, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'SIX OPERATION', 1 )
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN0 OPERATION', 1 ) -- must be abandon because of fork2
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN01 OPERATION', 1 ) -- must be abandon because of fork2
         , ( 9, 7, 0, 2, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN02 OPERATION', 1 ) -- must be abandon because of fork2
         , ( 7, 7, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN2 OPERATION', 2 )
         , ( 8, 7, 0, 1, 1, '2016-06-22 19:10:21-07'::timestamp, 'SEVEN21 OPERATION', 2 )
         , ( 9, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'EAIGHT2 OPERATION', 2 )
         , ( 10, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'NINE2 OPERATION', 2 )
         , ( 8, 8, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'EIGHT3 OPERATION', 3 )
         , ( 9, 9, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'NINE3 OPERATION', 3 )
         , ( 10, 10, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'TEN OPERATION', 3 )
    ;

    INSERT INTO hive.accounts
    VALUES
    ( 1, 'alice1', 1 )
         , ( 2, 'alice2', 2 )
         , ( 3, 'alice3', 3 )
         , ( 4, 'alice4', 4 )
    ;

    INSERT INTO hive.accounts_reversible
    VALUES
           ( 4, 'alice41', 4, 1 )
         , ( 5, 'alice51', 5, 1 )
         , ( 6, 'alice61', 6, 1 )
         , ( 7, 'alice71', 7, 1 ) -- must be overriden by fork 2
         , ( 8, 'bob71', 7, 1 )   -- must be overriden by fork 2
         , ( 9, 'alice81', 8, 1 ) -- must be overriden by fork 2
         , ( 9, 'alice91', 9, 2 ) -- must be overriden by fork 2
         , ( 7, 'alice72', 7, 2 )
         , ( 8, 'bob72', 7, 2 )
         , ( 10, 'alice92', 9, 2 )
         , ( 9, 'alice83', 8, 3 )
         , ( 10, 'alice93', 9, 3 )
         , ( 11, 'alice103', 10, 3 )
    ;

    INSERT INTO hive.account_operations(block_num, account_id, account_op_seq_no, operation_id, op_type_id)
    VALUES
           ( 1, 1, 1, 1, 1 )
         , ( 2, 1, 2, 2, 1 )
         , ( 2, 2, 1, 2, 1 )
         , ( 3, 3, 1, 3, 1 )
         , ( 4, 4, 1, 4, 1 )
    ;

    INSERT INTO hive.account_operations_reversible
    VALUES
           ( 4, 4, 1, 4, 1, 1 ) -- it pretends that some slow app prevent to remove this
         , ( 5, 5, 1, 5, 1, 1 )
         , ( 6, 6, 1, 6, 1, 1 )
         , ( 7, 7, 1, 7, 1, 1 ) -- must be overriden by fork 2
         , ( 7, 8, 1, 7, 1, 1 ) -- must be overriden by fork 2
         , ( 7, 9, 1, 9, 1, 1 ) -- must be overriden by fork 2
         , ( 7, 7, 2, 7, 1, 2 )
         , ( 7, 8, 2, 8, 1, 2 )
         , ( 8, 9, 2, 9, 1, 2 )
         , ( 7, 9, 3, 8, 1, 2 )
         , ( 9, 10, 2, 10, 1, 2 )
         , ( 9, 9, 3, 9, 1, 3 )
         , ( 10, 10, 3, 10, 1, 3 )
         , ( 10, 11, 3, 10, 1, 3 )
    ;

    UPDATE hive.irreversible_data SET consistent_block = 4;
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_when;
CREATE FUNCTION hived_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS HIVED
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_then;
CREATE FUNCTION hived_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS HIVED
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_when;
CREATE FUNCTION alice_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hive.blocks_view) > 0, 'Alice has no access to hive.blocks_view';
    ASSERT (SELECT COUNT(*) FROM hive.transactions_view) > 0, 'Alice has no access to hive.transactions_view';
    ASSERT (SELECT COUNT(*) FROM hive.transactions_multisig_view) > 0, 'Alice has no access to hive.transactions_multisig_view';
    ASSERT (SELECT COUNT(*) FROM hive.operations) > 0, 'Alice has no access to hive.operations';
    ASSERT (SELECT COUNT(*) FROM hive.accounts) > 0, 'Alice has no access to hive.accounts';
    ASSERT (SELECT COUNT(*) FROM hive.account_operations) > 0, 'Alice has no access to hive.account_operations';
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
    -- CHECK EXPECTED STATE AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_when;
CREATE FUNCTION bob_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_then;
CREATE FUNCTION bob_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS BOB
END;
$BODY$
;
