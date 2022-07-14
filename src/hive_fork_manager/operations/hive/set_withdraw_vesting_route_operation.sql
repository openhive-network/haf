CREATE TYPE hive.set_withdraw_vesting_route_operation AS (
  from_account hive.account_name_type,
  to_account hive.account_name_type,
  percent int4, -- uint16_t: 4 byte, but unsigned (int4)
  auto_vest boolean
);

SELECT _variant.create_cast_in( 'hive.set_withdraw_vesting_route_operation' );
SELECT _variant.create_cast_out( 'hive.set_withdraw_vesting_route_operation' );
