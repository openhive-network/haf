CREATE TYPE hive.hardfork_hive_restore_operation AS (
  account hive.account_name_type,
  treasury hive.account_name_type,
  hbd_transferred hive.asset,
  hive_transferred hive.asset
);

SELECT _variant.create_cast_in( 'hive.hardfork_hive_restore_operation' );
SELECT _variant.create_cast_out( 'hive.hardfork_hive_restore_operation' );
