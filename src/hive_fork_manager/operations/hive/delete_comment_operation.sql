CREATE TYPE hive.delete_comment_operation AS (
  author hive.account_name_type,
  permlink hive.permlink
);

SELECT _variant.create_cast_in( 'hive.delete_comment_operation' );
SELECT _variant.create_cast_out( 'hive.delete_comment_operation' );
