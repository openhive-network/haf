CREATE TABLE IF NOT EXISTS hafd.indexes_constraints (
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.indexes_constraints', '');
