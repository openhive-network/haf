-- Application registry (issue #341).
--
-- An application is a named group of contexts moved together by one processing
-- loop, plus the information a generic block-processing driver needs to run it:
-- the procedure to call for a delivered block range, whether the application is
-- paused, and which other applications it depends on. Dependencies gate block
-- delivery: hive.app_next_iteration / hive.app_next_block never hand an
-- application a block that any of its dependencies has not yet processed and
-- committed, so the dependency's tables are complete up to every block the
-- dependent sees. Processing order and parallelism follow from that gating alone;
-- no runner has to sequence applications itself.
--
-- These tables live in hafd so that they survive extension updates and are part
-- of dumps, like hafd.contexts.

CREATE TABLE IF NOT EXISTS hafd.applications(
    name TEXT NOT NULL,
    contexts TEXT[] NOT NULL,          -- contexts group; contexts[1] is the lead context
    process_procedure TEXT,            -- '<schema>.<procedure>' taking ( hive.blocks_range ), or NULL for
                                       -- self-driven applications that run their own loop
    completed_block_function TEXT,     -- '<schema>.<function>' returning INT: the highest block whose data
                                       -- this application has committed, for dependency gating; NULL means
                                       -- the contexts' current_block_num (right for every loop that commits
                                       -- the position together with the block's work)
    paused BOOL NOT NULL DEFAULT FALSE,
    owner NAME NOT NULL,
    CONSTRAINT pk_hive_applications PRIMARY KEY( name ),
    CONSTRAINT chk_hive_applications_name CHECK( LENGTH( name ) != 0 ),
    CONSTRAINT chk_hive_applications_contexts CHECK( CARDINALITY( contexts ) > 0 )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.applications', '');

CREATE INDEX IF NOT EXISTS hive_applications_contexts_idx ON hafd.applications USING GIN( contexts );

CREATE TABLE IF NOT EXISTS hafd.application_dependencies(
    application TEXT NOT NULL,
    depends_on TEXT NOT NULL,
    CONSTRAINT pk_hive_application_dependencies PRIMARY KEY( application, depends_on ),
    CONSTRAINT fk_hive_application_dependencies_application FOREIGN KEY( application ) REFERENCES hafd.applications( name ) ON DELETE CASCADE,
    CONSTRAINT fk_hive_application_dependencies_depends_on FOREIGN KEY( depends_on ) REFERENCES hafd.applications( name ) ON DELETE CASCADE,
    CONSTRAINT chk_hive_application_dependencies_self CHECK( application != depends_on )
);
SELECT pg_catalog.pg_extension_config_dump('hafd.application_dependencies', '');
