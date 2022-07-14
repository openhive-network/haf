CREATE TYPE hive.producer_reward_operation AS (
  producer hive.account_name_type,
  vesting_shares hive.asset
);

SELECT _variant.create_cast_in( 'hive.producer_reward_operation' );
SELECT _variant.create_cast_out( 'hive.producer_reward_operation' );
