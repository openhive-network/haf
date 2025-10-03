-- it contains log of contexts state changes

CREATE TYPE hafd.context_event AS ENUM(
        'CREATED'
      , 'ATTACHED'
      , 'DETACHED'
      , 'REMOVED'
      , 'STATE_CHANGED'
      , 'SLOW_PROCESSING'
);

CREATE TABLE hafd.contexts_log(
      id BIGSERIAL NOT NULL
    , context_name hafd.context_name NOT NULL -- we use name instead of context id to have info about  removed contexts
    , application_stage hafd.stage_name -- NULL allowed to support old fashion apps without stages
    , event_type hafd.context_event NOT NULL
    , date TIMESTAMP WITHOUT TIME ZONE NOT NULL
    , application_block INTEGER
    , application_fork BIGINT -- NULL when context was created before hived has started
    , head_block  INTEGER
    , head_fork_id BIGINT
    , CONSTRAINT pk_hive_contexts_log PRIMARY KEY( id )
);

CREATE INDEX IF NOT EXISTS hafd_contexts_log_context_name_idx ON hafd.contexts_log( context_name );

SELECT pg_catalog.pg_extension_config_dump('hafd.contexts_log', '');
SELECT pg_catalog.pg_extension_config_dump('hafd.contexts_log_id_seq', '');
-- it is not possible to make FK t check if block/fork in the table row exists
-- because reversible blocks are removed and a give pair og  block/fork may not exists any more
-- similar situation with contexts, which can be removed


