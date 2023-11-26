CREATE UNLOGGED TABLE IF NOT EXISTS hive.fork(
    id BIGSERIAL NOT NULL,
    block_num INT NOT NULL, -- head block number, after reverting all blocks from fork (look for `notify_switch_fork` in database.cpp hive project file )
    time_of_fork TIMESTAMP WITHOUT TIME ZONE NOT NULL, -- time of receiving notification from hived (see: hive.back_from_fork definition)
    CONSTRAINT pk_hive_fork PRIMARY KEY( id )
);
SELECT pg_catalog.pg_extension_config_dump('hive.fork', '');
SELECT pg_catalog.pg_extension_config_dump('hive.fork_id_seq', '');

