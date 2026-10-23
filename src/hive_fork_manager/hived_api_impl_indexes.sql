CREATE TYPE hafd.index_status AS ENUM ('missing', 'creating', 'created', 'invalid');

-- massive_sync_class says what a massive sync with psql-massive-index-policy=keep-monotonic
-- does with a core index of the irreversible tables:
--   'keep'  - left in place, it is maintained by hived's inserts
--   'defer' - dropped, and rebuilt when the massive sync ends
-- NULL marks rows the policy does not govern (foreign keys, reversible tables, app indexes).
-- A row gets hive.default_massive_sync_index_class() when it is first saved; an operator may
-- UPDATE it afterwards and later massive syncs keep the new value.
-- Existing installs get the column from hive_fork_manager_update_script_generator.sh
CREATE TABLE IF NOT EXISTS hafd.indexes_constraints (
    table_name text NOT NULL,
    index_constraint_name text NOT NULL,
    command text NOT NULL,
    is_constraint boolean NOT NULL,
    is_index boolean NOT NULL,
    is_foreign_key boolean NOT NULL,
    contexts int[] NOT NULL, 
    status hafd.index_status NOT NULL DEFAULT 'missing',
    massive_sync_class text,
    CONSTRAINT pk_hive_indexes_constraints UNIQUE( table_name, index_constraint_name ),
    CONSTRAINT indexes_constraints_massive_sync_class_check CHECK ( massive_sync_class IN ('keep', 'defer') )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.indexes_constraints', '');

-- The custom_json types each context wants indexed (hive.register_custom_json_type_index).
-- index_name is the index registered for them, NULL while some of the types have no id
-- in hafd.custom_json_types yet.
CREATE TABLE IF NOT EXISTS hafd.custom_json_type_index_requests (
    context_id integer NOT NULL,
    custom_json_ids text[] NOT NULL,
    index_name text,
    CONSTRAINT pk_hive_custom_json_type_index_requests PRIMARY KEY ( context_id ),
    CONSTRAINT fk_hive_custom_json_type_index_requests_context FOREIGN KEY ( context_id ) REFERENCES hafd.contexts( id ) ON DELETE CASCADE
);
SELECT pg_catalog.pg_extension_config_dump('hafd.custom_json_type_index_requests', '');

-- One vacuum request per table and kind:
--   'full'    - VACUUM FULL ANALYZE (rewrites the table and drops its visibility map)
--   'vacuum'  - VACUUM (ANALYZE)
--   'analyze' - ANALYZE
--   'freeze'  - VACUUM (FREEZE, ANALYZE)
-- skip_count and first_skip_time track the consecutive polls at which hived skipped the request
-- because its table stayed locked; they lengthen hived's lock wait and are cleared when the request ends.
-- Existing installs get the kind, skip_count and first_skip_time columns from hive_fork_manager_update_script_generator.sh
CREATE TYPE hafd.vacuum_status AS ENUM ('requested', 'vacuumed', 'failed');
CREATE TABLE IF NOT EXISTS hafd.vacuum_requests (
    schema_name text NOT NULL,
    table_name text NOT NULL,
    status hafd.vacuum_status NOT NULL DEFAULT 'requested',
    last_vacuumed_time timestamp,
    error_message text,
    kind text NOT NULL DEFAULT 'full',
    skip_count integer NOT NULL DEFAULT 0,
    first_skip_time timestamp,
    CONSTRAINT pk_hive_vacuum_requests UNIQUE( schema_name, table_name, kind ),
    CONSTRAINT vacuum_requests_kind_check CHECK ( kind IN ('full', 'vacuum', 'analyze', 'freeze') )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.vacuum_requests', '');
