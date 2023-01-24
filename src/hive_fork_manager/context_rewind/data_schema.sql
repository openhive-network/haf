-- New versions of PostgreSQL disallow to create schema if not exists statement for any object not belonging to extension, and given schema does not initially.

CREATE DOMAIN hive.context_name AS TEXT NOT NULL CONSTRAINT non_empty_context CHECK( LENGTH( VALUE ) != 0);
CREATE DOMAIN hive.contexts_group AS hive.context_name[] NOT NULL CONSTRAINT non_empty_contexts_group CHECK( CARDINALITY( VALUE ) > 0 );

CREATE TYPE hive.state_providers AS ENUM( 'ACCOUNTS', 'KEYAUTH' , 'METADATA', 'CURRENT_ACCOUNT_BALANCE_STATE_PROVIDER');

CREATE TYPE hive.event_type AS ENUM( 'BACK_FROM_FORK', 'NEW_BLOCK', 'NEW_IRREVERSIBLE', 'MASSIVE_SYNC' );

CREATE TABLE IF NOT EXISTS hive.contexts(
    id SERIAL NOT NULL,
    name hive.context_name NOT NULL,
    current_block_num INTEGER NOT NULL,
    irreversible_block INTEGER NOT NULL,
    is_attached BOOL NOT NULL,
    back_from_fork BOOL NOT NULL DEFAULT FALSE,
    events_id BIGINT NOT NULL DEFAULT 0, -- 0 - is a special fake event, means no events are processed, it is required to satisfy FK constraint
    fork_id BIGINT NOT NULL DEFAULT 1,
    owner NAME NOT NULL,
    detached_block_num INTEGER, -- place where application can save last processed block num in detached state
    registering_state_provider BOOL NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_hive_contexts PRIMARY KEY( id ),
    CONSTRAINT uq_hive_context_name UNIQUE ( name )
);
SELECT pg_catalog.pg_extension_config_dump('hive.contexts', '');
SELECT pg_catalog.pg_extension_config_dump('hive.contexts_id_seq', '');

CREATE INDEX IF NOT EXISTS hive_contexts_owner_idx ON hive.contexts( owner );

CREATE TABLE IF NOT EXISTS hive.registered_tables(
   id SERIAL NOT NULL,
   context_id INTEGER NOT NULL,
   origin_table_schema TEXT NOT NULL,
   origin_table_name TEXT NOT NULL,
   shadow_table_name TEXT NOT NULL,
   origin_table_columns TEXT[] NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT pk_hive_registered_tables PRIMARY KEY( id ),
   CONSTRAINT fk_hive_registered_tables_context FOREIGN KEY(context_id) REFERENCES hive.contexts( id ),
   CONSTRAINT uq_hive_registered_tables_register_table UNIQUE( origin_table_schema, origin_table_name )
);
SELECT pg_catalog.pg_extension_config_dump('hive.registered_tables', '');
SELECT pg_catalog.pg_extension_config_dump('hive.registered_tables_id_seq', '');


CREATE INDEX IF NOT EXISTS hive_registered_tables_context_idx ON hive.registered_tables( context_id );
CREATE INDEX IF NOT EXISTS hive_registered_tables_owder_idx ON hive.registered_tables( owner );


CREATE TABLE IF NOT EXISTS hive.triggers(
   id SERIAL PRIMARY KEY,
   registered_table_id INTEGER NOT NULL,
   trigger_name TEXT NOT NULL,
   function_name TEXT NOT NULL,
   owner NAME NOT NULL,
   CONSTRAINT fk_hive_triggers_registered_table FOREIGN KEY( registered_table_id ) REFERENCES hive.registered_tables( id ),
   CONSTRAINT uq_hive_triggers_registered_table UNIQUE( trigger_name )
);
SELECT pg_catalog.pg_extension_config_dump('hive.triggers', '');
SELECT pg_catalog.pg_extension_config_dump('hive.triggers_id_seq', '');

CREATE INDEX IF NOT EXISTS hive_registered_triggers_table_id ON hive.triggers( registered_table_id );
CREATE INDEX IF NOT EXISTS hive_triggers_owner_idx ON hive.triggers( owner );





