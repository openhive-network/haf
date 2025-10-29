-- start pruning function
--      registered two contexts on different current block
--      no blocks to prune
-- expected result:
--          nothing removed
--          check if accounts are not removed
-- start pruning function
--      registered two contexts on different current block
--      blocks to prune
-- expected result:
--          remove blocks lower than the lowest current block
--          check if accounts are not removed

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM test.fill_with_blocks_data();
    PERFORM hive.prune_blocks_data(4); -- remove all blocks that could be removed

    CREATE SCHEMA A;
    PERFORM hive.app_create_context(  _name =>'context1', _schema => 'a', _is_attached := FALSE );
    PERFORM hive.app_create_context(  _name =>'context2', _schema => 'a', _is_attached := FALSE );

    PERFORM hive.app_set_current_block_num( 'context1', 5 );
    PERFORM hive.app_set_current_block_num( 'context2', 4 );

    UPDATE hafd.contexts
    SET irreversible_block = 5
    WHERE name ='context1';

    UPDATE hafd.contexts
    SET irreversible_block = 3
    WHERE name ='context2';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.prune_blocks_data(2);
    -- nothing more was removed
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT (SELECT COUNT(*) FROM hafd.blocks) = 4, 'Too much blocks stay';
    ASSERT NOT EXISTS (SELECT 1 FROM hafd.blocks WHERE num = 1), 'block 1 was not removed';

    ASSERT (SELECT COUNT(*) FROM hafd.transactions) = 4, 'Some transactions stay';
    ASSERT (SELECT COUNT(*) FROM hafd.transactions_multisig) = 4, 'Some transactions multisig stay';
    ASSERT (SELECT COUNT(*) FROM hafd.operations) = 4, 'Some operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.account_operations) = 4, 'Some account operations stay';
    ASSERT (SELECT COUNT(*) FROM hafd.accounts) = 5, 'Number of accounts has changed';
END;
$BODY$
;