
CREATE TABLE IF NOT EXISTS hive.state_providers_registered(
      id SERIAL
    , context_id INTEGER NOT NULL
    , state_provider HIVE.STATE_PROVIDERS NOT NULL
    , tables TEXT[] NOT NULL
    , owner NAME NOT NULL
    , CONSTRAINT pk_hive_state_providers_registered PRIMARY KEY( id )
    , CONSTRAINT uq_hive_state_providers_registered_contexts_provider  UNIQUE ( context_id, state_provider )
    , CONSTRAINT fk_hive_state_providers_registered_context FOREIGN KEY( context_id ) REFERENCES hive.contexts( id )
);
SELECT pg_catalog.pg_extension_config_dump('hive.state_providers_registered', '');
SELECT pg_catalog.pg_extension_config_dump('hive.state_providers_registered_id_seq', '');

CREATE INDEX IF NOT EXISTS hive_state_providers_registered_idx ON hive.state_providers_registered( owner );
