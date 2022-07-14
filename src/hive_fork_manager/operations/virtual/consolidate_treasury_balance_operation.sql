CREATE TYPE hive.consolidate_treasury_balance_operation AS (
  total_moved hive.asset[]
);

SELECT _variant.create_cast_in( 'hive.consolidate_treasury_balance_operation' );
SELECT _variant.create_cast_out( 'hive.consolidate_treasury_balance_operation' );
