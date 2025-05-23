
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'OP 0', FALSE )
     , ( 1, 'OP 1', FALSE )
     , ( 2, 'OP 2', FALSE )
     , ( 3, 'OP 3', TRUE )
    ;

    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.back_from_fork( 1 );

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );


    INSERT INTO hafd.accounts_reversible
    VALUES ( 1, 'user', 2, 2 )
    ;

    INSERT INTO hafd.transactions_reversible
    VALUES
    ( 2, 0::SMALLINT, '\xDEED20', 101, 100, '2016-06-22 19:10:24-07'::timestamp, '\xBEEF',  2 )
    ;

    INSERT INTO hafd.operations_reversible(id, trx_in_block, op_pos, body_binary, fork_id)
    VALUES
    ( hafd.operation_id(2,1,0), 0, 0, '{"type":"system_warning_operation","value":{"message":"THREE OPERATION"}}' :: jsonb :: hafd.operation, 2 )
    ;

    INSERT INTO hafd.account_operations_reversible
    VALUES ( 1, 1, hafd.operation_id(2,1,0), 2 )
    ;


    INSERT INTO hafd.transactions_multisig_reversible
    VALUES
    ( '\xDEED20', '\xBEEF20',  2 );

    INSERT INTO hafd.applied_hardforks_reversible
    VALUES ( 1, 2, hafd.operation_id(2,1,0), 2 )
    ;

END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.set_irreversible( 2 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT * FROM hafd.transactions ), 'Transaction not landed in irreversible table';
    ASSERT EXISTS ( SELECT * FROM hafd.operations ), 'Operations not landed in irreversible table';
    ASSERT EXISTS ( SELECT * FROM hafd.transactions_multisig ), 'Signatures not landed in irreversible table';
    ASSERT EXISTS ( SELECT * FROM hafd.accounts ), 'Accounts not landed in irreversible table';
    ASSERT EXISTS ( SELECT * FROM hafd.account_operations ), 'Account operation not landed in irreversible table';
    ASSERT EXISTS ( SELECT * FROM hafd.applied_hardforks ), 'Hardforks not landed in irreversible table';
    ASSERT EXISTS ( SELECT * FROM hafd.blocks WHERE hash = '\xBADD20'::bytea ), 'block not landed in irreversible table';
END;
$BODY$
;




