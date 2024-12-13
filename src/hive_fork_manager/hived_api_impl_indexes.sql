CREATE TYPE hafd.index_status AS ENUM ('missing', 'creating', 'created', 'invalid');

CREATE TABLE IF NOT EXISTS hafd.indexes_constraints (
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    status hafd.index_status NOT NULL DEFAULT 'missing',
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.indexes_constraints', '');

CREATE TABLE IF NOT EXISTS hafd.context_indexes (
    context int NOT NULL,
    stage text,
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    CONSTRAINT uq_hive_context_indexes_context_stage UNIQUE( context, stage, table_name, index_constraint_name )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.context_indexes', '');
