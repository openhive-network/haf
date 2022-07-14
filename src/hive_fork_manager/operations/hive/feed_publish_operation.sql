CREATE TYPE hive.feed_publish_operation AS (
  publisher hive.account_name_type,
  exchange_rate hive.price
);

SELECT _variant.create_cast_in( 'hive.feed_publish_operation' );
SELECT _variant.create_cast_out( 'hive.feed_publish_operation' );
