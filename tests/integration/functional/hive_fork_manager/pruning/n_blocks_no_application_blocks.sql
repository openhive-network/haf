-- start pruning function
--      no registered contexts
--      blocks to prune exists
-- expected result:
--          stay at least 3 blocks
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
    PERFORM hive.prune_blocks_data(3);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hafd.blocks) = 4, 'Some blocks stay';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE num = 4), 'block 4 removed';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE num = 4), 'block 4 removed';
    ASSERT EXISTS (SELECT 1 FROM hafd.blocks WHERE num = 5), 'block 5 removed';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions) = 4, 'Some transactions stay';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions_multisig) = 4, 'Some transactions multisig stay';
    ASSERT (SELECT COUNT(*) FROM hafd.operations) = 4, 'Some operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.account_operations) = 4, 'Some account operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.accounts) = 5, 'Number of accounts has changed';
END;
$BODY$
;