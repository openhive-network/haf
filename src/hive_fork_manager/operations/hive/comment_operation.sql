CREATE TYPE hive.comment_operation AS (
  parent_author hive.account_name_type,
  parent_permlink hive.permlink,
  author hive.account_name_type,
  permlink hive.permlink,
  title hive.comment_title,
  body text,
  json_metadata text
);

SELECT _variant.create_cast_in( 'hive.comment_operation' );
SELECT _variant.create_cast_out( 'hive.comment_operation' );
