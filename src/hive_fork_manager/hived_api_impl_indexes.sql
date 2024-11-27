CREATE TYPE hafd.index_status AS ENUM ('missing', 'creating', 'created');
CREATE TABLE IF NOT EXISTS hafd.indexes_constraints (
    id SERIAL PRIMARY KEY,
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    status text NOT NULL DEFAULT 'missing',
    is_app_defined BOOLEAN NOT NULL DEFAULT FALSE,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.indexes_constraints', '');
SELECT pg_catalog.pg_extension_config_dump('hafd.indexes_constraints_id_seq', '');
