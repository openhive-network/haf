-- start pruning function
--      no registered contexts
--      blocks to prune not exist
-- expected result:
--          remove 5 blocks
--          check if accounts are not removed

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    INSERT INTO hafd.accounts( block_num, name, id )
    VALUES
           ( NULL, 'u1', 1 )
         , ( NULL, 'u2', 2 )
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