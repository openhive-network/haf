-- field block_num has different meaning for each event type
-- BACK_FROM_FORK - fork id
-- NEW_BLOCK - new block num
-- NEW_IRREVERSIBLE - new irreversible block
-- MASSIVE_SYNC - head of irreversible block after massive push by hived
CREATE TABLE IF NOT EXISTS hafd.events_queue(
      id BIGSERIAL PRIMARY KEY
    , event hafd.event_type NOT NULL
    , block_num BIGINT NOT NULL
);
SELECT pg_catalog.pg_extension_config_dump('hafd.events_queue', '');
SELECT pg_catalog.pg_extension_config_dump('hafd.events_queue_id_seq', '');

CREATE INDEX IF NOT EXISTS hive_events_queue_block_num_idx ON hafd.events_queue( block_num );
