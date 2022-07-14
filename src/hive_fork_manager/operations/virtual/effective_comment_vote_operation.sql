CREATE TYPE hive.effective_comment_vote_operation AS (
  voter hive.account_name_type,
  author hive.account_name_type,
  permlink hive.permlink,
  "weight" NUMERIC,
  rshares int8,
  total_vote_weight NUMERIC,
  pending_payout hive.asset
);

SELECT _variant.create_cast_in( 'hive.effective_comment_vote_operation' );
SELECT _variant.create_cast_out( 'hive.effective_comment_vote_operation' );
