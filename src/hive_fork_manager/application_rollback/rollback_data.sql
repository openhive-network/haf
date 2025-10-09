CREATE TABLE IF NOT EXISTS hafd.applications_transactions_register(
    id                   SERIAL PRIMARY KEY,
    name                 TEXT NOT NULL,
    owner                TEXT NOT NULL,
    current_app_tx_id    BIGINT NOT NULL DEFAULT 0,
    rollback_in_progress BOOLEAN NOT NULL DEFAULT FALSE,
    registered_tables    TEXT[] NOT NULL DEFAULT '{}' --full name schema.table_name
);

SELECT pg_catalog.pg_extension_config_dump('hafd.applications_transactions_register', '');
SELECT pg_catalog.pg_extension_config_dump('hafd.applications_transactions_register_id_seq', '');