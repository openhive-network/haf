
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
    PERFORM hive.update_state_provider_current_account_balance( 1, 5, 'context' );
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
 jb jsonb :=  '{"witness": "mottler-5", "block_id": "000330e07715f16ec5bd1115a25bcab2e0812144", "previous": "000330dfa558ca235b6992accc4255bf945dd61a", "timestamp": "2016-03-31T23:27:33", "extensions": [], "signing_key": "STM8CWrVbjUnDqMCn3TJcpzKPXxShsVGktLyoNCJbmj7Y1yVtbV9k", "transactions": [{"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "adrian", "amount": {"nai": "@@000000021", "amount": "466000", "precision": 3}}}], "signatures": ["20096508366fcb97c25b4383d6f8ccb4362d3331bb5a8d953c9382bc2a447050852030ac1c6a0947b34ae6a6f36b6230e9a3516975bd242cf50eb0e92daa141850"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "aftergut", "amount": {"nai": "@@000000021", "amount": "475000", "precision": 3}}}], "signatures": ["2013fc5d500aea12145694c67b8e67192e779538cef572081702a171be0532919e38b2f14a0a8e09970da5d82cbdddc8404126aad5eef6a68eea67428a00bc3563"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "aguilar", "amount": {"nai": "@@000000021", "amount": "231000", "precision": 3}}}], "signatures": ["1f7e994e8237762e5052f4829a81498b88c2393deb4ee440280e96838b56948fd5222ce27ff9c322acc60746d0ad05701a28e09a64c0f789619ea9990997a6608c"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "alpha", "amount": {"nai": "@@000000021", "amount": "125000", "precision": 3}}}], "signatures": ["2009f338e86433fd8ae396e383a86fd9348a1b1a562bca3e5b8bd2fe85249041114395cd0b81c208c9c9fb1da6a9cf4933a5e23e1d5115dc55f4544758c80bbade"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "analisa", "amount": {"nai": "@@000000021", "amount": "252000", "precision": 3}}}], "signatures": ["20074cdbd8f6c303b7fda0709e1ef198610bcedbea260fd73daa814f629e9150ff509a5cae34102e195f12c1419186fb12fb0a10c52e8c6cb65954d9c49d94f056"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "anastacia", "amount": {"nai": "@@000000021", "amount": "252000", "precision": 3}}}], "signatures": ["203f84d6f2417f96148d97980348d5a130d87b1ce0b49c88e1c98a54135812440e538af65980cf074977872a870930e17d063ef7b34d1e4f405951bbb47fe1c284"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "arroyo", "amount": {"nai": "@@000000021", "amount": "209000", "precision": 3}}}], "signatures": ["1f7a72823b9ef281ca3d4ba68b3897ca7866802513d1183becc973381c76112a787a6a685a112d392cbeb1d238b27953cf69c32daf7007c932bd365f54cc34d490"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "arsahk", "amount": {"nai": "@@000000021", "amount": "168000", "precision": 3}}}], "signatures": ["204962a10257ac6e3af902fa2c623536a82029c468e4e35399928fbb47b57179d4404ebb90ea6478efe212617b6e772b5826b0f5f2aaef59601a78f22eb2248b3b"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "ashleigh", "amount": {"nai": "@@000000021", "amount": "529000", "precision": 3}}}], "signatures": ["2034c24f7c7ce6898c1d83c2413b89b14a881c31532f8455e14c1eac7bccf046a40585e6de204232a7f1b4005d90e21b4be3134a19b416fe300a96770f6b59f39a"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "augusta", "amount": {"nai": "@@000000021", "amount": "548000", "precision": 3}}}], "signatures": ["2031f697997c205bee203ab309b1df6ed26b5e33327d8b4e33aaa1f37ee5ea440f6e9507761fb8580772f94a480c8e48e4857b6b8ae64425b3dd294e7bf323f24f"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "back", "amount": {"nai": "@@000000021", "amount": "104000", "precision": 3}}}], "signatures": ["20796427a811b721d729a8e26edf8eae0d3db735aa9f577e7aa1c11c3d5e5953405cfb1d16387c55875fe936ed3a3375e80350e681ffcbda7afcf72f6ec1ede714"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "barrie", "amount": {"nai": "@@000000021", "amount": "251000", "precision": 3}}}], "signatures": ["1f4fcba9fdf2d778a754ba64499d6d0a2833a32da103b6f5bc31f3865bb3042ea81b5273b9e058ef5bca9027300da67bb2815027d1f8428ce66e349e6e10109741"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "bavak", "amount": {"nai": "@@000000021", "amount": "491000", "precision": 3}}}], "signatures": ["206f3cfc050954f0f751c84747f2629d7571ea5ebef4f0af5c88b8e6de1398812b07ffd078251ff466e0c711e9c24e9a41a754a926f73fcc165f509873691becdf"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "bavihm", "amount": {"nai": "@@000000021", "amount": "420000", "precision": 3}}}], "signatures": ["20347f049bb228be0ecfb28f288ca985901fd4e2ad8c4b65b94a686cd88ecc4e285f816153b8d2f822844600df818d398d202399477b4522f0bd01bee3ba257f50"], "ref_block_num": 12511, "ref_block_prefix": 600463525}, {"expiration": "2016-03-31T23:28:00", "extensions": [], "operations": [{"type": "transfer_to_vesting_operation", "value": {"to": "", "from": "bendixen", "amount": {"nai": "@@000000021", "amount": "167000", "precision": 3}}}], "signatures": ["207f3fda354b058bed4a1ffadebf040829763367bb560b5ee34bebd5a45fd74d7d30364d286d1d3f967b72272425b29f0c0f4ae74ef101133d9accb37666e74469"], "ref_block_num": 12511, "ref_block_prefix": 600463525}], "transaction_ids": ["aecacf13d69b426f09af6ec75fbbbe7f0cf2413f", "9a63e5a46afea65f7a1a6c490d24ee9629ad7ba4", "193efe7f812e2743b3da7b8b40c354a6e4fb6fba", "856796f1f5c57b4c380aedfdd5a01f3820ffb7ec", "672d5285834a18aea87d0a9deae74e2875fc484a", "254235e3c10564f47323aba19f88b5e7b726a79a", "8c4b4e4250404db2c71aaa63b5ff43e4f7430635", "550fbc58985a9a6612015b231f8c753ca1c694ce", "74a7555d853a8caf6874871619fa8fe163953eb6", "6e4b22453f3adf7e7d2c5dbbb834b05cffa1b8d1", "9710598ca07fc4d83ed4ca15aca7257cefd4006d", "37f1c3bcaad337f32236dda33b4793c8f06ae624", "9be023b7c2d877338aca030e606043ecd6d5b12b", "0b9613601c1aa34687df7c226561331c17c49dba", "b38e5849de473d297a082cb2149ff4b1f8945ee5"], "witness_signature": "203455a89724de0fa5f44cfc83309cac96f576d26e8a418621b34ca211fb33515a7e68f1c4ab154a85e196970769c8a9203ad95baf4e9f87667ffbac44b5e7c355", "transaction_merkle_root": "a414fb4caca7e3b9c7313bc119ba9b793fdbfee3"}';
 last_block_num INTEGER;
BEGIN
    ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'initminer' and balance = 4000);
    ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'miners' and balance = 0);
    ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'null' and balance = 0);
    ASSERT EXISTS ( SELECT * FROM hive.context_current_account_balance WHERE account = 'temp' and balance = 0);
    ASSERT 4 = (SELECT COUNT(*) FROM hive.context_current_account_balance);
    
    PERFORM hive.app_state_provider_drop_all( 'context' );

END;
$BODY$
;

