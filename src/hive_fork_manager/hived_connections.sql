CREATE UNLOGGED TABLE IF NOT EXISTS hive.hived_connections(
    id BIGSERIAL NOT NULL,
    block_num INT NOT NULL,
    git_sha TEXT,
    time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    CONSTRAINT pk_hived_connections PRIMARY KEY( id )
);
SELECT pg_catalog.pg_extension_config_dump('hive.hived_connections', '');
SELECT pg_catalog.pg_extension_config_dump('hive.hived_connections_id_seq', '');

