CREATE TYPE hive.claim_account_operation AS (
  creator hive.account_name_type,
  fee hive.asset,
  extensions hive.extensions_type
);

SELECT _variant.create_cast_in( 'hive.claim_account_operation' );
SELECT _variant.create_cast_out( 'hive.claim_account_operation' );
