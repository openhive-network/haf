CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  CREATE EXTENSION IF NOT EXISTS btree_gin;
END
$BODY$;

CREATE OR REPLACE PROCEDURE test_hived_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 3, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
    ;
END
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA ALICE;
    PERFORM hive.app_create_context( _name => 'alice', _schema => 'alice' );

    UPDATE hafd.contexts
    SET
          last_active_at = last_active_at - '5 hrs'::interval
        , current_block_num = 2
    WHERE name = 'alice';
END
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  ASSERT hive.is_instance_ready(), 'Instance not ready';
END
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  ASSERT hive.is_instance_ready(), 'Instance not ready';
  -- Wait should return immediately, since we're not creating ny indices
  CALL hive.wait_till_registered_indexes_created('alice');
END
$BODY$;
