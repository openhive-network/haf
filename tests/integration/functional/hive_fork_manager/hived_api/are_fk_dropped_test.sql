-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.enable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- In the new schema, data tables no longer have foreign key constraints.
    -- The block_id encoding replaces the need for FKs.
    -- Since there are no FKs to manage, are_fk_dropped() returns TRUE
    -- (FKs are considered "dropped" because there are none).
    ASSERT ( SELECT hive.are_fk_dropped() ) = TRUE, 'Foreign keys should be considered dropped when none exist';
END;
$BODY$
;
