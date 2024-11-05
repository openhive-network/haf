-- it contains log of contexts state changes

CREATE TYPE hafd.context_event AS ENUM(
        'CREATED'
      , 'ATTACHED'
      , 'DETACHED'
      , 'REMOVED'
      , 'STATE_CHANGED'
);

CREATE TABLE hafd.contexts_log(
      context_id INTEGER
    , application_state hafd.stage_name -- can be null
    , event_type hafd.context_event
    , date TIMESTAMP WITHOUT TIME ZONE
    , application_block INTEGER NOT NULL
    , application_fork BIGINT NOT NULL
    , head_block  INTEGER NOT NULL
    , head_fork_id BIGINT NOT NULL
);

-- it is not possible to make FK t check if block/fork in the table row exists
-- because reversible blocks are removed and a give pair og  block/fork may not exists any more
-- similar situation with contexts, which can be removed
-- TODO(mickiewicz@syncad.com): what to do with entries when context is removed ?
--

