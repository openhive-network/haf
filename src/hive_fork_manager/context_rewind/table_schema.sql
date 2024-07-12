
CREATE TABLE IF NOT EXISTS hive.verify_table_schema(
    table_name hive.ctext NOT NULL,
    table_schema hive.ctext NOT NULL,
    table_schema_hash UUID,
    columns_hash UUID,
    constraints_hash UUID,
    indexes_hash UUID,
    table_columns hive.ctext NOT NULL,
    table_constraints hive.ctext NOT NULL,
    table_indexes hive.ctext NOT NULL
);

SELECT pg_catalog.pg_extension_config_dump('hive.verify_table_schema', '');

CREATE TABLE IF NOT EXISTS hive.table_schema(
    schema_name hive.ctext NOT NULL,
    schema_hash UUID NOT NULL
);

SELECT pg_catalog.pg_extension_config_dump('hive.table_schema', '');

