CREATE TYPE hive.author_reward_operation AS (
  author hive.account_name_type,
  permlink hive.permlink,
  hbd_payout hive.asset,
  hive_payout hive.asset,
  vesting_payout hive.asset,
  curators_vesting_payout hive.asset,
  payout_must_be_claimed boolean
);

SELECT _variant.create_cast_in( 'hive.author_reward_operation' );
SELECT _variant.create_cast_out( 'hive.author_reward_operation' );
