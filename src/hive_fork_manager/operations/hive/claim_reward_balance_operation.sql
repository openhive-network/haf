CREATE TYPE hive.claim_reward_balance_operation AS (
  account hive.account_name_type,
  reward_hive hive.asset,
  reward_hbd hive.asset,
  reward_vests hive.asset
);

SELECT _variant.create_cast_in( 'hive.claim_reward_balance_operation' );
SELECT _variant.create_cast_out( 'hive.claim_reward_balance_operation' );
