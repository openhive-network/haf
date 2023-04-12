DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
  _test0 hive.impacted_balances_return[];
  _test1 hive.impacted_balances_return[];
  _test2 hive.impacted_balances_return[];
  _test3 hive.impacted_balances_return[];
  _test4 hive.impacted_balances_return[];
  _test5 hive.impacted_balances_return[];
  _test6 hive.impacted_balances_return[];
  _test7 hive.impacted_balances_return[];
  _test8 hive.impacted_balances_return[];
  _test9 hive.impacted_balances_return[];
  _test10 hive.impacted_balances_return[];
  _test11 hive.impacted_balances_return[];
  _test12 hive.impacted_balances_return[];
  _test13 hive.impacted_balances_return[];
  _test14 hive.impacted_balances_return[];
  _test15 hive.impacted_balances_return[];
  _test16 hive.impacted_balances_return[];
  _test17 hive.impacted_balances_return[];
  _test18 hive.impacted_balances_return[];
  _test19 hive.impacted_balances_return[];
  _test20 hive.impacted_balances_return[];
  _test21 hive.impacted_balances_return[];
  _test22 hive.impacted_balances_return[];
  _test23 hive.impacted_balances_return[];
  _test24 hive.impacted_balances_return[];
  _test25 hive.impacted_balances_return[];
  _test26 hive.impacted_balances_return[];
  _test27 hive.impacted_balances_return[];
  _test28 hive.impacted_balances_return[];
  _test29 hive.impacted_balances_return[];
  _test30 hive.impacted_balances_return[];
  _test31 hive.impacted_balances_return[];
  _test32 hive.impacted_balances_return[];
  _test33 hive.impacted_balances_return[];
  _test34 hive.impacted_balances_return[];
  _test35 hive.impacted_balances_return[];
  _test36 hive.impacted_balances_return[];
  _test37 hive.impacted_balances_return[];
  _test38 hive.impacted_balances_return[];
  _test39 hive.impacted_balances_return[];
  _test40 hive.impacted_balances_return[];
  _test41 hive.impacted_balances_return[];
  _test42 hive.impacted_balances_return[];
  _test43 hive.impacted_balances_return[];
  _test44 hive.impacted_balances_return[];
  _test45 hive.impacted_balances_return[];
  _test46 hive.impacted_balances_return[];
  _test47 hive.impacted_balances_return[];
  _test48 hive.impacted_balances_return[];

BEGIN

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test0
FROM hive.get_impacted_balances('{"type":"vote_operation","value":{"voter":"flaminghedge","author":"doctorcrypto","permlink":"ridestory-north-rim-of-the-grand-canyon","weight":100}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test1
FROM hive.get_impacted_balances('{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"meta","author":"steemit","permlink":"firstpost","title":"Welcome to Steem!","body":"Steemit is a social media platform where anyone can earn STEEM points by posting. The more people who like a post, the more STEEM the poster earns. Anyone can sell their STEEM for cash or vest it to boost their voting power.","json_metadata":""}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test2
FROM hive.get_impacted_balances('{"type":"transfer_to_vesting_operation","value":{"from":"faddy","to":"","amount":{"amount":"357000","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test3
FROM hive.get_impacted_balances('{"type":"withdraw_vesting_operation","value":{"account":"steemit","vesting_shares":{"amount":"200000000000","precision":6,"nai":"@@000000037"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test4
FROM hive.get_impacted_balances('{"type":"limit_order_cancel_operation","value":{"owner":"linouxis9","orderid":10}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test5
FROM hive.get_impacted_balances('{"type":"feed_publish_operation","value":{"publisher":"abit","exchange_rate":{"base":{"amount":"1000","precision":3,"nai":"@@000000013"},"quote":{"amount":"1000000","precision":3,"nai":"@@000000021"}}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test6
FROM hive.get_impacted_balances('{"type":"proxy_cleared_operation","value":{"account":"lafona5","proxy":"lafona"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test7
FROM hive.get_impacted_balances('{"type":"account_update_operation","value":{"account":"theoretical","posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6FATHLohxTN8RWWkU9ZZwVywXo6MEDjHHui1jEBYkG2tTdvMYo",1],["STM76EQNV2RTA6yF9TnBvGSV71mW7eW36MM7XQp24JxdoArTfKA76",1]]},"memo_key":"STM6FATHLohxTN8RWWkU9ZZwVywXo6MEDjHHui1jEBYkG2tTdvMYo","json_metadata":""}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test8
FROM hive.get_impacted_balances('{"type":"witness_update_operation","value":{"owner":"dragosroua","url":"https://steemit.com/witness-category/@dragosroua/dragosroua-witness-thread","block_signing_key":"STM7yQ3BHxpgoeVhK9C4dua6BRj7EU3bnKCHLVxAxQ4bLWE4D9BDc","props":{"account_creation_fee":{"amount":"35287","precision":3,"nai":"@@000000021"},"maximum_block_size":65536,"hbd_interest_rate":1400},"fee":{"amount":"35287","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test9
FROM hive.get_impacted_balances('{"type":"account_witness_vote_operation","value":{"account":"donalddrumpf","witness":"berniesanders","approve":true}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test10
FROM hive.get_impacted_balances('{"type":"account_witness_proxy_operation","value":{"account":"bunkermining","proxy":"datasecuritynode"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test11
FROM hive.get_impacted_balances('{"type":"pow_operation","value":{"worker_account":"admin","block_id":"000004433bd4602cf5f74dbb564183837df9cef8","nonce":82,"work":{"worker":"STM65wH1LZ7BfSHcK69SShnqCAH5xdoSZpGkUjmzHJ5GCuxEK9V5G","input":"59b009f89477919f95914151cef06f28bf344dd6fb7670aca1c1f4323c80446b","signature":"1f3f83209097efcd01b7d6f27ce726164323d503d6fcf4d55bfb7cb3032796f6766738b36062b5850d69447fdf9c091cbc70825df5eeacc4710a0b11ffdbf0912a","work":"0b62f4837801cd857f01d6a541faeb13d6bb95f1c36c6b4b14a47df632aa6c92"},"props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test12
FROM hive.get_impacted_balances('{"type":"custom_operation","value":{"required_auths":["bytemaster"],"id":777,"data":"0a627974656d617374657207737465656d697402a3d13897d82114466ad87a74b73a53292d8331d1bd1d3082da6bfbcff19ed097029db013797711c88cccca3692407f9ff9b9ce7221aaa2d797f1692be2215d0a5f6d2a8cab6832050078bc5729201e3ea24ea9f7873e6dbdc65a6bd9899053b9acda876dc69f11a13df9ca8b26b6"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test13
FROM hive.get_impacted_balances('{"type":"delete_comment_operation","value":{"author":"jsc","permlink":"test-delete"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test14
FROM hive.get_impacted_balances('{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["supergeek75"],"id":"follow","json":"[\"follow\",{\"follower\":\"supergeek75\",\"following\":\"niko77\",\"what\":[\"blog\"]}]"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test15
FROM hive.get_impacted_balances('{"type":"comment_options_operation","value":{"author":"testing001","permlink":"testing6","max_accepted_payout":{"amount":"1000000","precision":3,"nai":"@@000000013"},"percent_hbd":5000,"allow_votes":true,"allow_curation_rewards":true,"extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test16
FROM hive.get_impacted_balances('{"type":"set_withdraw_vesting_route_operation","value":{"from_account":"newyo6","to_account":"newyo","percent":10000,"auto_vest":true}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test18
FROM hive.get_impacted_balances('{"type":"create_claimed_account_operation","value":{"creator":"blocktrades","new_account_name":"gatherex","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8JH4fTJr73FQimysjmXCEh2UvRwZsG6ftjxsVTmYCeEehZgh25",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6Gp4f7tdDBCu2MV1ZNjUQBw54Nmmmr6axq36qX9sWY7GQQjdY1",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM81yUciDyjJR6jxMRz7oWLR8jmaJchx4tjqt3XmAcWH3xAqbEV3",1]]},"memo_key":"STM7bUBovHJUbsXhkYz9x6JPg36MF7WAsYZKtaudVopBCoJKetuLQ","json_metadata":"{}","extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test19
FROM hive.get_impacted_balances('{"type":"request_account_recovery_operation","value":{"recovery_account":"steem","account_to_recover":"gandalf","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6LYxj96zdypHYqgDdD6Nyh2NxerN3P1Mp3ddNm7gci63nfrSuZ",1]]},"extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test20
FROM hive.get_impacted_balances('{"type":"recover_account_operation","value":{"account_to_recover":"chitty","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7j3nhkhHTpXqLEvdx2yEGhQeeorTcxSV6WDL2DZGxwUxYGrHvh",1]]},"recent_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM78Xth94gNxp8nmByFV2vNAhg9bsSdviJ6fQXUTFikySLK3uTxC",1]]},"extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test21
FROM hive.get_impacted_balances('{"type":"change_recovery_account_operation","value":{"account_to_recover":"barrie","new_recovery_account":"boombastic","extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test22
FROM hive.get_impacted_balances('{"type":"escrow_dispute_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"anonymtest","escrow_id":72526562}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test23
FROM hive.get_impacted_balances('{"type":"pow2_operation","value":{"work":{"type":"pow2","value":{"input":{"worker_account":"aizen06","prev_block":"003ea604345523c344fbadab605073ea712dd76f","nonce":"1052853013628665497"},"pow_summary":3817904373}},"props":{"account_creation_fee":{"amount":"1","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test24
FROM hive.get_impacted_balances('{"type":"escrow_approve_operation","value":{"from":"xtar","to":"testz","agent":"on0tole","who":"on0tole","escrow_id":59102208,"approve":true}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test25
FROM hive.get_impacted_balances('{"type":"transfer_from_savings_operation","value":{"from":"abit","request_id":101,"to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test26
FROM hive.get_impacted_balances('{"type":"cancel_transfer_from_savings_operation","value":{"from":"jesta","request_id":1}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test27
FROM hive.get_impacted_balances('{"type":"decline_voting_rights_operation","value":{"account":"bilalhaider","decline":true}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test28
FROM hive.get_impacted_balances('{"type":"delegate_vesting_shares_operation","value":{"delegator":"liberosist","delegatee":"dunia","vesting_shares":{"amount":"94599167138276","precision":6,"nai":"@@000000037"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test29
FROM hive.get_impacted_balances('{"type":"witness_set_properties_operation","value":{"owner":"holger80","props":[["account_creation_fee","b80b00000000000003535445454d0000"],["key","0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"]],"extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test30
FROM hive.get_impacted_balances('{"type":"account_update2_operation","value":{"account":"tftest1","json_metadata":"","posting_json_metadata":"{\"profile\":{\"about\":\"Testing account by @travelfeed\",\"couchsurfing\":\"cstest\",\"facebook\":\"facebooktest\",\"instagram\":\"instatest\",\"twitter\":\"twittertest\",\"website\":\"https://test.test\",\"youtube\":\"youtubetest\"}}","extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test31
FROM hive.get_impacted_balances('{"type":"create_proposal_operation","value":{"creator":"gtg","receiver":"steem.dao","start_date":"2019-08-27T00:00:00","end_date":"2029-12-31T23:59:59","daily_pay":{"amount":"240000000000","precision":3,"nai":"@@000000013"},"subject":"Return Proposal","permlink":"steemdao","extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test32
FROM hive.get_impacted_balances('{"type":"update_proposal_votes_operation","value":{"voter":"gtg","proposal_ids":[0,1],"approve":true,"extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test33
FROM hive.get_impacted_balances('{"type":"remove_proposal_operation","value":{"proposal_owner":"asgarth-dev","proposal_ids":[5],"extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test34
FROM hive.get_impacted_balances('{"type":"update_proposal_operation","value":{"proposal_id":139,"creator":"asgarth-dev","daily_pay":{"amount":"999","precision":3,"nai":"@@000000013"},"subject":"Test proposal for DHF related tests","permlink":"test-proposal-for-dhf-related-developments","extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test35
FROM hive.get_impacted_balances('{"type":"recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","recurrence":24,"executions":5,"extensions":[]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test36
FROM hive.get_impacted_balances('{"type":"comment_reward_operation","value":{"author":"abit","permlink":"hard-fork-18-how-to-use-author-reward-splitting-feature","payout":{"amount":"2137","precision":3,"nai":"@@000000013"},"author_rewards":3432,"total_payout_value":{"amount":"575","precision":3,"nai":"@@000000013"},"curator_payout_value":{"amount":"216","precision":3,"nai":"@@000000013"},"beneficiary_payout_value":{"amount":"1345","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test37
FROM hive.get_impacted_balances('{"type":"shutdown_witness_operation","value":{"owner":"mining1"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test38
FROM hive.get_impacted_balances('{"type":"clear_null_account_balance_operation","value":{"total_cleared":[{"amount":"2000","precision":3,"nai":"@@000000021"},{"amount":"21702525","precision":3,"nai":"@@000000013"}]}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test39
FROM hive.get_impacted_balances('{"type":"hardfork_hive_operation","value":{"account":"abduhawab","treasury":"steem.dao","other_affected_accounts":[],"hbd_transferred":{"amount":"0","precision":3,"nai":"@@000000013"},"hive_transferred":{"amount":"0","precision":3,"nai":"@@000000021"},"vests_converted":{"amount":"0","precision":6,"nai":"@@000000037"},"total_hive_from_vests":{"amount":"0","precision":3,"nai":"@@000000021"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test40
FROM hive.get_impacted_balances('{"type":"delayed_voting_operation","value":{"voter":"balte","votes":"33105558106560"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test41
FROM hive.get_impacted_balances('{"type":"effective_comment_vote_operation","value":{"voter":"lillianjones","author":"andrarchy","permlink":"leaving-dubrovnik-cable-car-view-of-the-city-and-a-tour-of-my-apartment","weight":"3758931741336","rshares":63085782,"total_vote_weight":"16349949220593993796","pending_payout":{"amount":"96526","precision":3,"nai":"@@000000013"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test42
FROM hive.get_impacted_balances('{"type":"ineffective_delete_comment_operation","value":{"author":"jsc","permlink":"re-vadimberkut8-just-test-20160603t163718014z"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test43
FROM hive.get_impacted_balances('{"type":"expired_account_notification_operation","value":{"account":"spiritrider"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test44
FROM hive.get_impacted_balances('{"type":"changed_recovery_account_operation","value":{"account":"barrie","old_recovery_account":"boombastic","new_recovery_account":"boombastic"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test45
FROM hive.get_impacted_balances('{"type":"vesting_shares_split_operation","value":{"owner":"gru1234-242","vesting_shares_before_split":{"amount":"17094","precision":6,"nai":"@@000000037"},"vesting_shares_after_split":{"amount":"17094000000","precision":6,"nai":"@@000000037"}}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test46
FROM hive.get_impacted_balances('{"type":"system_warning_operation","value":{"message":"Changing maximum block size from 2097152 to 131072"}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test47
FROM hive.get_impacted_balances('{"type":"failed_recurrent_transfer_operation","value":{"from":"blackknight1423","to":"aa111","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"","consecutive_failures":1,"remaining_executions":0,"deleted":false}}', FALSE) f
;

SELECT ARRAY_AGG(ROW(f.account_name, f.amount, f.asset_precision, f.asset_symbol_nai)::hive.impacted_balances_return)
INTO _test48
FROM hive.get_impacted_balances('{"type":"producer_missed_operation","value":{"producer":"dantheman5"}}', FALSE) f
;

ASSERT _test0 is null, 'Broken impacted balances result in "vote_operation" method';
ASSERT _test1 is null, 'Broken impacted balances result in "comment_operation" method';
ASSERT _test2 is null, 'Broken impacted balances result in "transfer_to_vesting_operation" method';
ASSERT _test3 is null, 'Broken impacted balances result in "withdraw_vesting_operation" method';
ASSERT _test4 is null, 'Broken impacted balances result in "limit_order_cancel_operation" method';
ASSERT _test5 is null, 'Broken impacted balances result in "feed_publish_operation" method';
ASSERT _test6 is null, 'Broken impacted balances result in "proxy_cleared_operation" method';
ASSERT _test7 is null, 'Broken impacted balances result in "account_update_operation" method';
ASSERT _test8 is null, 'Broken impacted balances result in "witness_update_operation" method';
ASSERT _test9 is null, 'Broken impacted balances result in "account_witness_vote_operation" method';
ASSERT _test10 is null, 'Broken impacted balances result in "account_witness_proxy_operation" method';
ASSERT _test11 is null, 'Broken impacted balances result in "pow_operation" method';
ASSERT _test12 is null, 'Broken impacted balances result in "custom_operation" method';
ASSERT _test13 is null, 'Broken impacted balances result in "delete_comment_operation" method';
ASSERT _test14 is null, 'Broken impacted balances result in "custom_json_operation" method';
ASSERT _test15 is null, 'Broken impacted balances result in "comment_options_operation" method';
ASSERT _test16 is null, 'Broken impacted balances result in "set_withdraw_vesting_route_operation" method';
ASSERT _test18 is null, 'Broken impacted balances result in "create_claimed_account_operation" method';
ASSERT _test19 is null, 'Broken impacted balances result in "request_account_recovery_operation" method';
ASSERT _test20 is null, 'Broken impacted balances result in "recover_account_operation" method';
ASSERT _test21 is null, 'Broken impacted balances result in "change_recovery_account_operation" method';
ASSERT _test22 is null, 'Broken impacted balances result in "escrow_dispute_operation" method';
ASSERT _test23 is null, 'Broken impacted balances result in "pow2_operation" method';
ASSERT _test24 is null, 'Broken impacted balances result in "escrow_approve_operation" method';
ASSERT _test25 is null, 'Broken impacted balances result in "transfer_from_savings_operation" method';
ASSERT _test26 is null, 'Broken impacted balances result in "cancel_transfer_from_savings_operation" method';
ASSERT _test27 is null, 'Broken impacted balances result in "decline_voting_rights_operation" method';
ASSERT _test28 is null, 'Broken impacted balances result in "delegate_vesting_shares_operation" method';
ASSERT _test29 is null, 'Broken impacted balances result in "witness_set_properties_operation" method';
ASSERT _test30 is null, 'Broken impacted balances result in "account_update2_operation" method';
ASSERT _test31 is null, 'Broken impacted balances result in "create_proposal_operation" method';
ASSERT _test32 is null, 'Broken impacted balances result in "update_proposal_votes_operation" method';
ASSERT _test33 is null, 'Broken impacted balances result in "remove_proposal_operation" method';
ASSERT _test34 is null, 'Broken impacted balances result in "update_proposal_operation" method';
ASSERT _test35 is null, 'Broken impacted balances result in "recurrent_transfer_operation" method';
ASSERT _test36 is null, 'Broken impacted balances result in "comment_reward_operation" method';
ASSERT _test37 is null, 'Broken impacted balances result in "shutdown_witness_operation" method';
ASSERT _test38 is null, 'Broken impacted balances result in "clear_null_account_balance_operation" method';
ASSERT _test39 is null, 'Broken impacted balances result in "hardfork_hive_operation" method';
ASSERT _test40 is null, 'Broken impacted balances result in "delayed_voting_operation" method';
ASSERT _test41 is null, 'Broken impacted balances result in "effective_comment_vote_operation" method';
ASSERT _test42 is null, 'Broken impacted balances result in "ineffective_delete_comment_operation" method';
ASSERT _test43 is null, 'Broken impacted balances result in "expired_account_notification_operation" method';
ASSERT _test44 is null, 'Broken impacted balances result in "changed_recovery_account_operation" method';
ASSERT _test45 is null, 'Broken impacted balances result in "vesting_shares_split_operation" method';
ASSERT _test46 is null, 'Broken impacted balances result in "system_warning_operation" method';
ASSERT _test47 is null, 'Broken impacted balances result in "failed_recurrent_transfer_operation" method';
ASSERT _test48 is null, 'Broken impacted balances result in "producer_missed_operation" method';

END;
$BODY$
;


