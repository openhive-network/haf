CREATE SCHEMA hash AUTHORIZATION haf_admin;

CREATE TABLE IF NOT EXISTS hive.table_schema(
    table_name TEXT NOT NULL,
    table_schema_hash UUID,
    columns_hash UUID,
    constraints_hash UUID,
    indexes_hash UUID,
    table_columns TEXT NOT NULL,
    table_constraints TEXT NOT NULL,
    table_indexes TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS hive.verify_table_schema(
    table_name TEXT NOT NULL,
    columns_hash UUID,
    constraints_hash UUID,
    indexes_hash UUID
);

CREATE TABLE IF NOT EXISTS hive.verify_table_schema_string(
    table_name TEXT NOT NULL,
    columns_hash TEXT NOT NULL,
    constraints_hash TEXT NOT NULL,
    indexes_hash TEXT NOT NULL
);

