DROP TYPE IF EXISTS hive.event_type CASCADE;
CREATE TYPE hive.event_type AS ENUM( 'BACK_FROM_FORK', 'NEW_BLOCK', 'NEW_IRREVERSIBLE', 'MASSIVE_SYNC' );

-- field block_num has different meaning for each event type
-- BACK_FROM_FORK - fork id
-- NEW_BLOCK - new block num
-- NEW_IRREVERSIBLE - new irreversible block
-- MASSIVE_SYNC - head of irreversible block after massive push by hived
CREATE TABLE IF NOT EXISTS hive.events_queue(
      id BIGSERIAL PRIMARY KEY
    , event hive.event_type NOT NULL
    , block_num BIGINT NOT NULL
);
SELECT pg_catalog.pg_extension_config_dump('hive.events_queue', '');

INSERT INTO hive.events_queue VALUES( 0, 'NEW_IRREVERSIBLE', 0 ) ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS hive_events_queue_block_num_idx ON hive.events_queue( block_num );