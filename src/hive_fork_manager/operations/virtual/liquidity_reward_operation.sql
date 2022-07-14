CREATE TYPE hive.liquidity_reward_operation AS (
  "owner" hive.account_name_type,
  payout hive.asset
);

SELECT _variant.create_cast_in( 'hive.liquidity_reward_operation' );
SELECT _variant.create_cast_out( 'hive.liquidity_reward_operation' );
