CREATE TYPE hive.curation_reward_operation AS (
  curator hive.account_name_type,
  reward hive.asset,
  comment_author hive.account_name_type,
  comment_permlink hive.permlink,
  payout_must_be_claimed boolean
);

SELECT _variant.create_cast_in( 'hive.curation_reward_operation' );
SELECT _variant.create_cast_out( 'hive.curation_reward_operation' );
