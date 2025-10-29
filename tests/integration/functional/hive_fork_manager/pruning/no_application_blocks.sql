-- start pruning function
--      no registered contexts
--      blocks to prune exists
-- expected result:
--          remove all blocks data
--          check if accounts are not removed

-- start pruning function
--      no registered contexts
--      blocks to prune no  exists
-- expected result:
--          remove 4 blocks
--          check if accounts are not removed

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM test.fill_with_blocks_data();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.prune_blocks_data();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hafd.blocks) = 2, 'Some blocks stay';
    ASSERT (SELECT MAX(num) FROM hafd.blocks) = 5, 'Wrong blocks removed';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions) = 2, 'Some transactions stay';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions_multisig) = 2, 'Some transactions multisig stay';
    ASSERT (SELECT COUNT(*) FROM hafd.operations) = 2, 'Some operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.account_operations) = 1, 'Some account operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.accounts) = 5, 'Number of accounts has changed';
END;
$BODY$
;