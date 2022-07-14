-- TODO: Move to hive schema
CREATE DOMAIN hive_future_extensions AS variant.variant;
SELECT variant.register('hive_future_extensions', '{ hive.void_t }');

CREATE DOMAIN hive.extensions_type AS hive_future_extensions[];
