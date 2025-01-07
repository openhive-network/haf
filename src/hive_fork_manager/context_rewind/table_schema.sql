CREATE TABLE IF NOT EXISTS hafd.table_schema(
    schema_name TEXT NOT NULL,
    schema_hash UUID NOT NULL
);

SELECT pg_catalog.pg_extension_config_dump('hafd.table_schema', '');



