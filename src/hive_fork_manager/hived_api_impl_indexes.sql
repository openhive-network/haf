CREATE TYPE hafd.index_status AS ENUM ('missing', 'creating', 'created', 'invalid');

CREATE TABLE IF NOT EXISTS hafd.indexes_constraints (
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    contexts int[] NOT NULL, 
    status hafd.index_status NOT NULL DEFAULT 'missing',
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.indexes_constraints', '');

-- Only one vacuum request per table, and this is only for 'vacuum full analyze' requests
CREATE TYPE hafd.vacuum_status AS ENUM ('requested', 'vacuuming', 'vacuumed', 'failed');
CREATE TABLE IF NOT EXISTS hafd.vacuum_requests (
    table_name text NOT NULL,
    hafd.vacuum_status,
    last_vacuumed_time timestamp,
    CONSTRAINT pk_hive_vacuum_requests UNIQUE( table_name)
);
