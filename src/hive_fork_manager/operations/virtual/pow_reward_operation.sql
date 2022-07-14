CREATE TYPE hive.pow_reward_operation AS (
  worker hive.account_name_type,
  reward hive.asset
);

SELECT _variant.create_cast_in( 'hive.pow_reward_operation' );
SELECT _variant.create_cast_out( 'hive.pow_reward_operation' );
