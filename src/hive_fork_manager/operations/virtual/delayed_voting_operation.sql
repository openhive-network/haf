CREATE TYPE hive.delayed_voting_operation AS (
  voter hive.account_name_type,
  votes hive.ushare_type
);

SELECT _variant.create_cast_in( 'hive.delayed_voting_operation' );
SELECT _variant.create_cast_out( 'hive.delayed_voting_operation' );
