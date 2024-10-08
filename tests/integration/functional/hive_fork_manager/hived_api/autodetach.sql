CREATE OR REPLACE PROCEDURE test_hived_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hive_data.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA ALICE;
    PERFORM hive.app_create_context( _name => 'alice', _schema => 'alice' );

    UPDATE hive_data.contexts
    SET
          last_active_at = last_active_at - '5 hrs'::interval
        , current_block_num = 2
    WHERE name = 'alice';

    PERFORM hive.app_create_context( _name => 'alice_not_detached', _schema => 'alice' );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE bob_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA BOB;
    PERFORM hive.app_create_context( _name => 'bob', _schema => 'bob' );

    UPDATE hive_data.contexts
    SET
        last_active_at = last_active_at - '15 hrs'::interval
      , current_block_num = 3
    WHERE name = 'bob';
END
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- pretend we are calling from a cron job
    SET ROLE haf_maintainer;
    CALL hive.proc_perform_dead_app_contexts_auto_detach();
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.app_context_is_attached( 'alice' ) = FALSE, 'alice is still attached';
    ASSERT ( SELECT hive.app_get_current_block_num( 'alice' ) = 2 ), 'wrong alice current block';
    ASSERT hive.app_context_is_attached( 'bob' ) = FALSE, 'bob is still attached';
    ASSERT ( SELECT hive.app_get_current_block_num( 'bob' ) = 3 ), 'wrong bob current block';
    ASSERT hive.app_context_is_attached( 'alice_not_detached' ) = TRUE, 'alice_not_detached is detached';
END
$BODY$
;
