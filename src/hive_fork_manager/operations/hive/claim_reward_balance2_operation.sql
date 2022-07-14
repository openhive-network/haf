CREATE TYPE hive.claim_reward_balance2_operation AS (
  account hive.account_name_type,
  extensions hive.extensions_type,
  reward_tokens hive.asset[]
);

SELECT _variant.create_cast_in( 'hive.claim_reward_balance2_operation' );
SELECT _variant.create_cast_out( 'hive.claim_reward_balance2_operation' );
