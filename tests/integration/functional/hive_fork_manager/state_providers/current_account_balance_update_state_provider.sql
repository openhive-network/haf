-- CURRENT_ACCOUNT_BALANCE state provider allocates an object during hive.app_state_provider_import on the C++ side
-- Both hive.update_state_provider_current_account_balance and hive.app_state_provider_drop_all operate on that object
-- But test_given, test_when  and test_then are called from different processes
-- That's why everything needs to be done in one function (test_given in this case) 


DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (1, '\x0000000109833ce528d5bbfb3f6225b39ee10086', '\x0000000000000000000000000000000000000000', '2016-03-24 16:05:00', 3, '\x0000000000000000000000000000000000000000', NULL, '\x204f8ad56a8f5cf722a02b035a61b500aa59b9519b2c33c77a80c0a714680a5a5a7a340d909d19996613c5e4ae92146b9add8a7a663eef37d837ef881477313043', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 2000, 3000, 3000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (2, '\x00000002ed04e3c3def0238f693931ee7eebbdf1', '\x0000000109833ce528d5bbfb3f6225b39ee10086', '2016-03-24 16:05:36', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f3e85ab301a600f391f11e859240f090a9404f8ebf0bf98df58eb17f455156e2d16e1dcfc621acb3a7acbedc86b6d2560fdd87ce5709e80fa333a2bbb92966df3', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 4000, 6000, 6000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (3, '\x000000035b094a812646289c622dba0ba67d1ffe', '\x00000002ed04e3c3def0238f693931ee7eebbdf1', '2016-03-24 16:05:39', 3, '\x0000000000000000000000000000000000000000', NULL, '\x205ad1d3f0d42abcfdacb179de1acecf873be432cc546dde6b35184d261868b47b17dc1717b78a1572843fdd71a654e057db03f2df5d846b71606ec80455a199a6', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 6000, 9000, 9000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (4, '\x00000004f9de0cfeb08c9d7d9d1fe536d902dc4a', '\x000000035b094a812646289c622dba0ba67d1ffe', '2016-03-24 16:05:42', 3, '\x0000000000000000000000000000000000000000', NULL, '\x202c7e5cada5104170365a83734a229eac0e427af5ed03fe2268e79bb9b05903d55cb96547987b57cd1ba5ed1a5ae1a9372f0ee6becfd871c2fcc26dc8b057149e', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 8000, 12000, 12000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (5, '\x00000005014b5562a1133070d8bee536de615329', '\x00000004f9de0cfeb08c9d7d9d1fe536d902dc4a', '2016-03-24 16:05:45', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f508f1124db7f1442946b5e3b3a5f822812e54e18dffcda83385a9664b825d27214f0cdd0a0a7e7aeb6467f428fbc291c6f64b60da29e8ad182c20daf71b68b8b', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 10000, 15000, 15000, 0, 0);

    INSERT INTO hive.accounts (id, name, block_num) VALUES (0, 'miners', 1);
    INSERT INTO hive.accounts (id, name, block_num) VALUES (1, 'null', 1);
    INSERT INTO hive.accounts (id, name, block_num) VALUES (2, 'temp', 1);
    INSERT INTO hive.accounts (id, name, block_num) VALUES (3, 'initminer', 1);

  
    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_state_provider_import( 'CURRENT_ACCOUNT_BALANCE', 'context' );
    PERFORM hive.app_context_detach( 'context' );

    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 5;
    -- PERFORM hive.update_state_provider_current_account_balance( 1, 5, 'context' );


    --PERFORM hive.app_state_provider_drop_all( 'context' );

END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'initminer' and balance = 4000), 'ASSERT1';
    -- ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'miners' and balance = 0),'ASSERT2';
    -- ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'null' and balance = 0);
    -- ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'temp' and balance = 0);
    -- ASSERT 4 = (SELECT COUNT(*) FROM hive.context_current_account_balance);
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
DECLARE
BEGIN
END;
$BODY$
;

