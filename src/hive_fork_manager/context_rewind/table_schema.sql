
CREATE UNLOGGED TABLE IF NOT EXISTS hive.verify_table_schema(
    table_name TEXT NOT NULL,
    table_schema TEXT NOT NULL,
    table_schema_hash UUID,
    columns_hash UUID,
    constraints_hash UUID,
    indexes_hash UUID,
    table_columns TEXT NOT NULL,
    table_constraints TEXT NOT NULL,
    table_indexes TEXT NOT NULL
);

SELECT pg_catalog.pg_extension_config_dump('hive.verify_table_schema', '');

CREATE UNLOGGED TABLE IF NOT EXISTS hive.table_schema(
    schema_name TEXT NOT NULL,
    schema_hash UUID NOT NULL
);

SELECT pg_catalog.pg_extension_config_dump('hive.table_schema', '');

