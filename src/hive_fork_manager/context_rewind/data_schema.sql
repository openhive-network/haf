-- New versions of PostgreSQL disallow to create schema if not exists statement for any object not belonging to extension, and given schema does not initially.

CREATE DOMAIN hive_data.context_name AS TEXT NOT NULL CONSTRAINT non_empty_context CHECK( LENGTH( VALUE ) != 0);
CREATE DOMAIN hive_data.contexts_group AS hive_data.context_name[] NOT NULL CONSTRAINT non_empty_contexts_group CHECK( CARDINALITY( VALUE ) > 0 );

CREATE TYPE hive_data.state_providers AS ENUM( 'ACCOUNTS', 'KEYAUTH' , 'METADATA' );

CREATE TYPE hive_data.event_type AS ENUM( 'BACK_FROM_FORK', 'NEW_BLOCK', 'NEW_IRREVERSIBLE', 'MASSIVE_SYNC' );

CREATE TABLE IF NOT EXISTS hive_data.contexts(
    id SERIAL NOT NULL,
    name hive_data.context_name NOT NULL,
    schema TEXT NOT NULL,
    current_block_num INTEGER NOT NULL,
    irreversible_block INTEGER NOT NULL,
    back_from_fork BOOL NOT NULL DEFAULT FALSE,
    events_id BIGINT NOT NULL DEFAULT 0, -- 0 - is a special fake event, means no events are processed, it is required to satisfy FK constraint
    fork_id BIGINT NOT NULL DEFAULT 1,
    owner NAME NOT NULL,
    registering_state_provider BOOL NOT NULL DEFAULT FALSE,
    is_forking BOOL NOT NULL DEFAULT TRUE,
    last_active_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, -- Stores last app activity time (updated by apps APIs like app_next_block)
    baseclass_id REGCLASS NOT NULL, -- id of context base table
    stages hive_data.application_stages,
    loop hive_data.application_loop_state,
    CONSTRAINT pk_hive_contexts PRIMARY KEY( id ),
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);
SELECT pg_catalog.pg_extension_config_dump('hive_data.contexts', '');
SELECT pg_catalog.pg_extension_config_dump('hive_data.contexts_id_seq', '');

CREATE INDEX IF NOT EXISTS hive_contexts_owner_idx ON hive_data.contexts( owner );

CREATE TABLE IF NOT EXISTS hive_data.contexts_attachment(
      context_id INTEGER NOT NULL UNIQUE
    , is_attached BOOL NOT NULL
    , owner NAME NOT NULL
    , CONSTRAINT fk_contexts_attachment_context FOREIGN KEY(context_id) REFERENCES hive_data.contexts( id )
);
SELECT pg_catalog.pg_extension_config_dump('hive_data.contexts_attachment', '');

CREATE INDEX IF NOT EXISTS hive_contexts_attachment_owner_idx ON hive_data.contexts_attachment( owner );

CREATE TABLE IF NOT EXISTS hive_data.registered_tables(
   id SERIAL NOT NULL,
   context_id INTEGER NOT NULL,
   origin_table_schema TEXT NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT pk_hive_registered_tables PRIMARY KEY( id ),
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hive_data.contexts( id ),
   CONSTRAINT uq_hive_registered_tables_register_table UNIQUE( origin_table_schema, origin_table_name )
);
SELECT pg_catalog.pg_extension_config_dump('hive_data.registered_tables', '');
SELECT pg_catalog.pg_extension_config_dump('hive_data.registered_tables_id_seq', '');


CREATE INDEX IF NOT EXISTS hive_registered_tables_context_idx ON hive_data.registered_tables( context_id );
CREATE INDEX IF NOT EXISTS hive_registered_tables_owder_idx ON hive_data.registered_tables( owner );


CREATE TABLE IF NOT EXISTS hive_data.triggers(
   id SERIAL PRIMARY KEY,
   registered_table_id INTEGER NOT NULL,
   trigger_name TEXT NOT NULL,
   function_name TEXT NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive_data.registered_tables( id ),
   CONSTRAINT uq_hive_triggers_registered_table UNIQUE( trigger_name )
);
SELECT pg_catalog.pg_extension_config_dump('hive_data.triggers', '');
SELECT pg_catalog.pg_extension_config_dump('hive_data.triggers_id_seq', '');

CREATE INDEX IF NOT EXISTS hive_registered_triggers_table_id ON hive_data.triggers( registered_table_id );
CREATE INDEX IF NOT EXISTS hive_triggers_owner_idx ON hive_data.triggers( owner );





