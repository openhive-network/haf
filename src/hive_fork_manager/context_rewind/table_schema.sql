CREATE TYPE hafd.verify_table_schema AS(
    table_name TEXT,
    table_schema TEXT,
    table_schema_hash UUID,
    columns_hash UUID,
    constraints_hash UUID,
    indexes_hash UUID,
    table_columns TEXT,
    table_constraints TEXT,
    table_indexes TEXT
);

CREATE TABLE IF NOT EXISTS hafd.table_schema(
    schema_name TEXT NOT NULL,
    schema_hash UUID NOT NULL
);

SELECT pg_catalog.pg_extension_config_dump('hafd.table_schema', '');

CREATE TYPE hafd.state_provider_and_hash AS(
    provider hafd.state_providers,
    hash TEXT
);

