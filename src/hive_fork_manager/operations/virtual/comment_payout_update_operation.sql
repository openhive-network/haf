CREATE TYPE hive.comment_payout_update_operation AS (
  author hive.account_name_type,
  permlink hive.permlink
);

SELECT _variant.create_cast_in( 'hive.comment_payout_update_operation' );
SELECT _variant.create_cast_out( 'hive.comment_payout_update_operation' );
