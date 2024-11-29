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
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_1', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_1 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_2', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_2 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_3', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_3 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_4', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_4 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_5', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_5 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_6', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_6 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_7', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_7 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  CALL hive.register_app_index('alice', 'hafd.operations', 'hive_operations_vote_author_permlink_8', '
CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink_8 ON hafd.operations USING gin
(
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),
    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')
)
WHERE hive.operation_id_to_type_id(id) = 0');
  -- Make the session a little longer to check that the worker can access the data
  PERFORM pg_sleep(1);
END
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  ASSERT hive.is_instance_ready(), 'Instance not ready';
  CALL hive.wait_till_registered_indexes_created('alice');
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_1'), 'Index hive_operations_vote_author_permlink_1 was not cerated';
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_2'), 'Index hive_operations_vote_author_permlink_2 was not cerated';
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_3'), 'Index hive_operations_vote_author_permlink_3 was not cerated';
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_4'), 'Index hive_operations_vote_author_permlink_4 was not cerated';
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_5'), 'Index hive_operations_vote_author_permlink_5 was not cerated';
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_6'), 'Index hive_operations_vote_author_permlink_6 was not cerated';
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_7'), 'Index hive_operations_vote_author_permlink_7 was not cerated';
  ASSERT hive.is_index_exists('hafd', 'operations', 'hive_operations_vote_author_permlink_8'), 'Index hive_operations_vote_author_permlink_8 was not cerated';
END
$BODY$;
