-- PROCEDURES needed here instead of functions, because pqxx library can see changes only after COMMIT;

-- include postgres map/dictionary for this test
CREATE EXTENSION IF NOT EXISTS hstore;


DROP PROCEDURE IF EXISTS haf_admin_procedure_test_given;
CREATE PROCEDURE haf_admin_procedure_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
BEGIN

    RAISE NOTICE 'Storing consensus provider data in %', toolbox.get_consensus_storage_path();

    INSERT INTO hive.operation_types (id, name, is_virtual) VALUES
        (0,	'hive::protocol::vote_operation',	false),
        (1,	'hive::protocol::comment_operation',	false),
        (2,	'hive::protocol::transfer_operation',	false),
        (64,	'hive::protocol::producer_reward_operation',	true);

    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (1, '\x0000000109833ce528d5bbfb3f6225b39ee10086', '\x0000000000000000000000000000000000000000', '2016-03-24 16:05:00', 3, '\x0000000000000000000000000000000000000000', NULL, '\x204f8ad56a8f5cf722a02b035a61b500aa59b9519b2c33c77a80c0a714680a5a5a7a340d909d19996613c5e4ae92146b9add8a7a663eef37d837ef881477313043', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 2000, 3000, 3000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (2, '\x00000002ed04e3c3def0238f693931ee7eebbdf1', '\x0000000109833ce528d5bbfb3f6225b39ee10086', '2016-03-24 16:05:36', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f3e85ab301a600f391f11e859240f090a9404f8ebf0bf98df58eb17f455156e2d16e1dcfc621acb3a7acbedc86b6d2560fdd87ce5709e80fa333a2bbb92966df3', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 4000, 6000, 6000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (3, '\x000000035b094a812646289c622dba0ba67d1ffe', '\x00000002ed04e3c3def0238f693931ee7eebbdf1', '2016-03-24 16:05:39', 3, '\x0000000000000000000000000000000000000000', NULL, '\x205ad1d3f0d42abcfdacb179de1acecf873be432cc546dde6b35184d261868b47b17dc1717b78a1572843fdd71a654e057db03f2df5d846b71606ec80455a199a6', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 6000, 9000, 9000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (4, '\x00000004f9de0cfeb08c9d7d9d1fe536d902dc4a', '\x000000035b094a812646289c622dba0ba67d1ffe', '2016-03-24 16:05:42', 3, '\x0000000000000000000000000000000000000000', NULL, '\x202c7e5cada5104170365a83734a229eac0e427af5ed03fe2268e79bb9b05903d55cb96547987b57cd1ba5ed1a5ae1a9372f0ee6becfd871c2fcc26dc8b057149e', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 8000, 12000, 12000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger) VALUES (5, '\x00000005014b5562a1133070d8bee536de615329', '\x00000004f9de0cfeb08c9d7d9d1fe536d902dc4a', '2016-03-24 16:05:45', 3, '\x0000000000000000000000000000000000000000', NULL, '\x1f508f1124db7f1442946b5e3b3a5f822812e54e18dffcda83385a9664b825d27214f0cdd0a0a7e7aeb6467f428fbc291c6f64b60da29e8ad182c20daf71b68b8b', 'STM8GC13uCZbP44HzMLV6zPZGwVQ8Nt4Kji8PapsPiNq1BK153XTX', 0, 1000, 1000000, 10000, 15000, 15000, 0, 0);
    INSERT INTO hive.blocks (num, hash, prev, created_at, producer_account_id, transaction_merkle_root, extensions, witness_signature, signing_key, hbd_interest_rate, total_vesting_fund_hive, total_vesting_shares, total_reward_fund_hive, virtual_supply, current_supply, current_hbd_supply, dhf_interval_ledger)  VALUES ( 6,	'\x0000639e34695ff8eb7d1049088173f56b6e4e45', '\x00000005014b5562a1133070d8bee536de615329',	'2016-03-25 13:49:06',	3, '\x9eac6e309a064ec9591f85e91a6945e4d238c86e', 	NULL, '\x202443c61a843c3ee623d9d8fe1af19fcff37f2e4a8075a02dac6a9110fae0961f20901f5ed23e8a4a2d458dce12b9c06171f497e474f1ca5550297e9b54c6b92b','STM66YCjksmFrAvFtT5zJrLYrahd2KreiqqwoxSwxbVyE5BQGhebJ',	1000,224000,224000000	,51004000,	102441000,	102441000,	0,	0);

    INSERT INTO hive.transactions (block_num, trx_in_block, trx_hash, ref_block_num, ref_block_prefix, expiration, signature) VALUES
                                  (6, 0, '\x4bf285b77aa9efc2d29d82b4a545dde0ef68a9fe',	25501	, 4211555470, 	'2016-03-24T16:30:45', '\x204ffd40d4feefdf309780a62058e7944b6833595c500603f3bb66ddbbca2ea661391196a97aa7dde53fdcca8aeb31f8c63aee4f47a20238f3749d9f4cb77f03f5');
                                                                                                                    
    INSERT INTO hive.operations VALUES
                                (28817,	6,	0,	0,	2,	'2016-03-25 13:49:03', '{"type":"transfer_operation","value":{"from":"initminer","to":"miners","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"mtlk_transaction"}}':: jsonb :: hive.operation);
    INSERT INTO hive.operations VALUES
                                (28818,	6,	-1,	1,	64,	'2016-03-25 13:49:06', '{"type":"producer_reward_operation","value":{"producer":"emily","vesting_shares":{"amount":"1000","precision":3,"nai":"@@000000021"}}}':: jsonb :: hive.operation);

    INSERT INTO  hive.accounts  (id, name, block_num) VALUES 
                                (0	,'miners',	1),
                                (1	,'null',	1),
                                (2	,'temp',	1),
                                (3	,'initminer',	1),
                                (48,	'steemit16',	1),
                                (224,	'emily',	1);


    PERFORM hive.app_create_context( 'context' );
    
    ASSERT  NOT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context'), 'Sessions table should not contain ''context'' entry before hive.create_session (via app_state_provider_import)';

    -- creates csp_session
    PERFORM hive.app_state_provider_import( 'CSP', 'context' , toolbox.get_consensus_storage_path());

    -- check if sessions table is filled
    ASSERT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context'), 'Sessions table should contain ''context'' entry after hive.create_session (via app_state_provider_import)';

    PERFORM hive.app_context_detach( 'context' );
    UPDATE hive.contexts SET current_block_num = 1, irreversible_block = 5;
    COMMIT;

    __session_ptr = hive.get_session_ptr('context');
    RAISE NOTICE '__session_ptr=%', __session_ptr;
    RAISE NOTICE 'sesion_consensus_state_provider_get_expected_block_num = %', 
        hive.consensus_state_provider_get_expected_block_num(__session_ptr);

    --disconnect sessions because we are leaving the current process
    PERFORM hive.sessions_disconnect();
    
END;
$BODY$
;


DROP PROCEDURE IF EXISTS haf_admin_procedure_test_when;
CREATE PROCEDURE haf_admin_procedure_test_when()
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
    BEGIN

    PERFORM hive.sessions_reconnect();
    __session_ptr = hive.get_session_ptr('context');

    ASSERT 1 = (SELECT * FROM hive.consensus_state_provider_get_expected_block_num(__session_ptr)),
                             'consensus_state_provider_get_expected_block_num should return 1';
    PERFORM hive.update_state_provider_csp( 1, 6, 'context' );
    COMMIT;

    PERFORM hive.sessions_disconnect();
END;
$BODY$
LANGUAGE 'plpgsql';

DROP PROCEDURE IF EXISTS haf_admin_procedure_test_then;
CREATE PROCEDURE haf_admin_procedure_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    rec RECORD;
    expected hstore := '"miners"=>"1000", "initminer"=>"4000"';
    actual hstore := '';
    __session_ptr BIGINT;
BEGIN

    RAISE NOTICE 'haf_admin_procedure_test_then 10';
    PERFORM hive.sessions_reconnect();
    __session_ptr = hive.get_session_ptr('context');


    RAISE NOTICE 'in then consensus_state_provider_get_expected_block_num=%',(SELECT * FROM hive.consensus_state_provider_get_expected_block_num(__session_ptr));    

    RAISE NOTICE 'haf_admin_procedure_test_then 20';

    FOR rec IN SELECT * FROM hive.current_account_balances(__session_ptr, akeys(expected)) LOOP
        RAISE NOTICE 'haf_admin_procedure_test_then 30';
        actual := actual || format('"%s"=>"%s"', rec.account, rec.balance)::hstore;
    END LOOP;  

    RAISE NOTICE 'haf_admin_procedure_test_then 40';


    ASSERT expected = actual, 'Expected: ' || expected::TEXT  || ' but got: ' ||  actual::TEXT;

    RAISE NOTICE 'haf_admin_procedure_test_then 50';


    ASSERT 7 = (SELECT * FROM hive.consensus_state_provider_get_expected_block_num(__session_ptr)),
        'consensus_state_provider_get_expected_block_num should return 7';
    ASSERT EXISTS ( SELECT * FROM hive.context_csp WHERE account = 'initminer' AND balance = 4000), 'Incorrect balance of initminer';
    ASSERT EXISTS ( SELECT * FROM hive.context_csp WHERE account = 'miners' AND balance = 1000),'Incorrect balance of miners';
    ASSERT EXISTS ( SELECT * FROM hive.context_csp WHERE account = 'null' AND balance = 0), 'Incorrect balance of null';
    ASSERT EXISTS ( SELECT * FROM hive.context_csp WHERE account = 'temp' AND balance = 0), 'Incorrect balance of temp';
    ASSERT 5 = ( SELECT COUNT(*) FROM hive.context_csp), 'Incorrect number of accounts';

    ASSERT (SELECT to_regclass('hive.context_csp')) IS NOT NULL, 'State provider table should exist';

    ASSERT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context');

    PERFORM hive.app_state_provider_drop_all( 'context' ), 'Sessions table should contain ''context'' entry before hive.destroy_session (via app_state_provider_drop_all)';

    ASSERT  NOT EXISTS (SELECT 1 FROM hive.sessions WHERE name = 'context'), 'Sessions table should not contain ''context'' entry after hive.destroy_session (via app_state_provider_drop_all)';

    -- ASSERT (SELECT to_regclass('hive.context_current_account_balance')) IS NULL, 'State provider table should not exist';
END;
$BODY$
;

