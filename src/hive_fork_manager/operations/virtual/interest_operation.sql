CREATE TYPE hive.interest_operation AS (
  "owner" hive.account_name_type,
  interest hive.asset
);

SELECT _variant.create_cast_in( 'hive.interest_operation' );
SELECT _variant.create_cast_out( 'hive.interest_operation' );
