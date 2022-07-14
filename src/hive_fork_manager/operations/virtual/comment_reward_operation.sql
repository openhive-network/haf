CREATE TYPE hive.comment_reward_operation AS (
  author hive.account_name_type,
  permlink hive.permlink,
  payout hive.asset,
  author_rewards hive.share_type,
  total_payout_value hive.asset,
  curator_payout_value hive.asset,
  beneficiary_payout_value hive.asset
);

SELECT _variant.create_cast_in( 'hive.comment_reward_operation' );
SELECT _variant.create_cast_out( 'hive.comment_reward_operation' );
