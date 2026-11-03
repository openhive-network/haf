CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.operation_types
    VALUES (0, 'ZERO OPERATION', FALSE )
        , ( 1, 'ONE OPERATION', FALSE )
    ;

    INSERT INTO hafd.blocks
    VALUES
       ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
     , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;

    INSERT INTO hafd.operations
    VALUES
           ( hafd.operation_id(1, 0), 0, 1, 0, '{"message":"ZERO OPERATION"}'::jsonb )
         , ( hafd.operation_id(3, 0), 0, 1, 0, '{"message":"ONE OPERATION"}'::jsonb )
    ;

    INSERT INTO hafd.account_operations
    VALUES
          ( 5, 5, 1, hafd.operation_id(1, 0), 0 )
        , ( 6, 6, 1, hafd.operation_id(3, 0), 0 )
    ;

    -- all three blocks are irreversible and consistent, as after a finished replay
    PERFORM hive.end_massive_sync( 3 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- hived state starts below the database's irreversible data, e.g. after --force-replay
    PERFORM hive.connect( '123456789', 1, 1, 0 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hafd.blocks ) = 3, 'Unexpected number of blocks';
    ASSERT ( SELECT MAX(num) FROM hafd.blocks ) = 3, 'Irreversible top block changed';
    ASSERT ( SELECT COUNT(*) FROM hafd.operations ) = 2, 'Unexpected number of operations';
    ASSERT ( SELECT COUNT(*) FROM hafd.account_operations ) = 2, 'Unexpected number of account_operations';

    ASSERT ( SELECT COUNT(*) FROM hafd.hived_connections ) = 0, 'Connection saved although it was refused';
    ASSERT ( SELECT COUNT(*) FROM hafd.fork ) = 1, 'Fork added although connection was refused';
END
$BODY$
;
