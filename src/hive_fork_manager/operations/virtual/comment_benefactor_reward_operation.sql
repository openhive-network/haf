CREATE TYPE hive.comment_benefactor_reward_operation AS (
  benefactor hive.account_name_type,
  author hive.account_name_type,
  permlink hive.permlink,
  hbd_payout hive.asset,
  hive_payout hive.asset,
  vesting_payout hive.asset
);

SELECT _variant.create_cast_in( 'hive.comment_benefactor_reward_operation' );
SELECT _variant.create_cast_out( 'hive.comment_benefactor_reward_operation' );
