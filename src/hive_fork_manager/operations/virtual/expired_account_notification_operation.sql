CREATE TYPE hive.expired_account_notification_operation AS (
  account hive.account_name_type
);

SELECT _variant.create_cast_in( 'hive.expired_account_notification_operation' );
SELECT _variant.create_cast_out( 'hive.expired_account_notification_operation' );
