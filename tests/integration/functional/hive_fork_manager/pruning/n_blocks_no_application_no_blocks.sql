-- start pruning function
--      no registered contexts
--      blocks to prune not exist
-- expected result:
--          remove 5 blocks
--          check if accounts are not removed

-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create 2 accounts with NULL block_id (not associated with any block)
    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES
      ( 1, 'u1', NULL )
    , ( 2, 'u2', NULL )
    ;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- TODO(mickiewicz@syncad.com): i'm not sre if hived will call prune
    PERFORM hive.prune_blocks_data(5);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hafd.accounts) = 2, 'Number of accounts has changed';
END;
$BODY$
;
