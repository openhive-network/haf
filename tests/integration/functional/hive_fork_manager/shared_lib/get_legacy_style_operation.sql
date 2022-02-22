DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    --Nothing to do
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

  vote_operation = {"type":"vote_operation","value":{"voter":"andzzz","author":"signalandnoise","permlink":"hello-","weight":-10000}}
  comment_operation = {"type":"comment_operation","value":{"parent_author":"steemit","parent_permlink":"firstpost","author":"admin","permlink":"firstpost","title":"","body":"First Reply! Let's get this **party** started","json_metadata":""}}
  transfer_operation = {"type":"transfer_operation","value":{"from":"faddy3","to":"faddy","amount":{"amount":"40000","precision":3,"nai":"@@000000021"},"memo":""}}
  transfer_to_vesting_operation = {"type":"transfer_to_vesting_operation","value":{"from":"steemit70","to":"steemit","amount":{"amount":"100000","precision":3,"nai":"@@000000021"}}}
  withdraw_vesting_operation = {"type":"withdraw_vesting_operation","value":{"account":"randaletouri","vesting_shares":{"amount":"2753463","precision":6,"nai":"@@000000037"}}}
  limit_order_create_operation = {"type":"limit_order_create_operation","value":{"owner":"adm","orderid":1,"amount_to_sell":{"amount":"1000","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"1000","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2016-05-31T21:44:00"}}
  limit_order_cancel_operation = {"type":"limit_order_cancel_operation","value":{"owner":"steempty","orderid":533}}
  feed_publish_operation = {"type":"feed_publish_operation","value":{"publisher":"abit","exchange_rate":{"base":{"amount":"15000","precision":3,"nai":"@@000000013"},"quote":{"amount":"2000","precision":3,"nai":"@@000000021"}}}}
  convert_operation = {"type":"convert_operation","value":{"owner":"summon","requestid":1467592168,"amount":{"amount":"5000","precision":3,"nai":"@@000000013"}}}
  account_create_operation = {"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"hello","new_account_name":"usd","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5b4i9gBqvh4sbgrooXPu2dbGLewNPZkXeuNeBjyiswnu2szgXx",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7ko5nzqaYfjbD4tKWGmiy3xtT9eQFZ3Pcmq5JmygTRptWSiVQy",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5xAKxnMT2y9VoVJdF63K8xRQAohsiQy9bA33aHeyMB5vgkzaay",1]]},"memo_key":"STM8ZSyzjPm48GmUuMSRufkVYkwYbZzbxeMysAVp7KFQwbTf98TcG","json_metadata":"{}"}}
  account_update_operation = {"type":"account_update_operation","value":{"account":"theoretical","posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM76EQNV2RTA6yF9TnBvGSV71mW7eW36MM7XQp24JxdoArTfKA76",1]]},"memo_key":"STM6FATHLohxTN8RWWkU9ZZwVywXo6MEDjHHui1jEBYkG2tTdvMYo","json_metadata":""}}
  witness_update_operation = {"type":"witness_update_operation","value":{"owner":"ihashfury","url":"https://steemit.com/witness-category/@ihashfury/ihashfury-witness-thread","block_signing_key":"STM8aUs6SGoEmNYMd3bYjE1UBr6NQPxGWmTqTdBaxJYSx244edSB2","props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}
  account_witness_vote_operation = {"type":"account_witness_vote_operation","value":{"account":"steemit","witness":"modprobe","approve":true}}
  account_witness_proxy_operation = {"type":"account_witness_proxy_operation","value":{"account":"aphrodite","proxy":"datasecuritynode"}}
  pow_operation = {"type":"pow_operation","value":{"worker_account":"dark","block_id":"000004433bd4602cf5f74dbb564183837df9cef8","nonce":60,"work":{"worker":"STM5QPFyb4ANmtoaubh4iEtDd1DJvx5jxJYKbFtLExdVjKdGkQo44","input":"fece42ada3ac23101e3c4ee18f6eccc69d6f8710c7b29b496e0a7ad0c128af2c","signature":"2018233fbb20c9a8543604b8edf7ff1ff1bbea22c52a1eabf9592c0316909c4e080d5b4b1ea1a66a7024de10ec3c2b1dbff8c696bfccdee78aca4d560430d33964","work":"0d8423b0fa3d87ed8c3f8dd9c0f79884da8966a1fd1501b27212918f15dfb72e"},"props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}
  custom_operation = {"type":"custom_operation","value":{"required_auths":["bytemaster"],"id":777,"data":"0a627974656d617374657207737465656d697402a3d13897d82114466ad87a74b73a53292d8331d1bd1d3082da6bfbcff19ed097029db013797711c88cccca3692407f9ff9b9ce7221aaa2d797f1692be2215d0a5f607de8b06d3205000ff825a32029a2df80c7cc67d0179fc54d87e4d795f4209b8aeebc93ada0fce7092f92b6d8"}}
  delete_comment_operation = {"type":"delete_comment_operation","value":{"author":"jsc","permlink":"re-abit-test1-20160606t212217819z"}}
  custom_json_operation = {"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["jsc"],"id":"follow","json":"{\"follower\":\"jsc\",\"following\":\"officialfuzzy\",\"what\":[\"posts\"]}"}}
  comment_options_operation = {"type":"comment_options_operation","value":{"author":"freebornangel","permlink":"it-s-an-info-war-bad-no-info-you-lose","max_accepted_payout":{"amount":"1000000000","precision":3,"nai":"@@000000013"},"percent_hbd":0,"allow_votes":true,"allow_curation_rewards":true,"extensions":[]}}
  set_withdraw_vesting_route_operation = {"type":"set_withdraw_vesting_route_operation","value":{"from_account":"newyo6","to_account":"newyo","percent":10000,"auto_vest":true}}
  request_account_recovery_operation = {"type":"request_account_recovery_operation","value":{"recovery_account":"steem","account_to_recover":"boatymcboatface","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM61RC4KGbmXNyfk7mmmh2PETAzb4qMm4c5L4maf2oVoAR6aeGJq",1]]},"extensions":[]}}
  recover_account_operation = {"type":"recover_account_operation","value":{"account_to_recover":"steemychicken1","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM82miH8qam2G2WPPjgyquPBrUbenGDHjhZMxqaKqCugWhcuqZzW",1]]},"recent_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6Wf68LVi22QC9eS8LBWykRiSrKKp5RTWXcNqjh3VPNhiT9xFxx",1]]},"extensions":[]}}
  change_recovery_account_operation = {"type":"change_recovery_account_operation","value":{"account_to_recover":"bingo-0","new_recovery_account":"boombastic","extensions":[]}}
  pow2_operation = {"type":"pow2_operation","value":{"work":{"type":"pow2","value":{"input":{"worker_account":"b0y2k31","prev_block":"003ea73c674962ad0e406d6d49736092b43fb385","nonce":"219420911219087363"},"pow_summary":3858814423}},"props":{"account_creation_fee":{"amount":"1","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}
  fill_convert_request_operation = {"type":"fill_convert_request_operation","value":{"owner":"summon","requestid":1467592168,"amount_in":{"amount":"5000","precision":3,"nai":"@@000000013"},"amount_out":{"amount":"18867","precision":3,"nai":"@@000000021"}}}
  author_reward_operation = {"type":"author_reward_operation","value":{"author":"anon","permlink":"that-cool-two-handed-puppet-is-back-with-a-dancing-video","hbd_payout":{"amount":"9","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"0","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"235563374","precision":6,"nai":"@@000000037"},"curators_vesting_payout":{"amount":"455422524","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}
  curation_reward_operation = {"type":"curation_reward_operation","value":{"curator":"juanlibertad","reward":{"amount":"800915474","precision":6,"nai":"@@000000037"},"comment_author":"chris4210","comment_permlink":"why-brexit-may-not-happen-real-house-of-cards-similarities-to-the-dao","payout_must_be_claimed":false}}
  comment_reward_operation = {"type":"comment_reward_operation","value":{"author":"ceviche","permlink":"rhubarb-season","payout":{"amount":"938640","precision":3,"nai":"@@000000013"},"author_rewards":2133281,"total_payout_value":{"amount":"469321","precision":3,"nai":"@@000000013"},"curator_payout_value":{"amount":"469318","precision":3,"nai":"@@000000013"},"beneficiary_payout_value":{"amount":"0","precision":3,"nai":"@@000000013"}}}
  liquidity_reward_operation = {"type":"liquidity_reward_operation","value":{"owner":"adm","payout":{"amount":"1200000","precision":3,"nai":"@@000000021"}}}
  interest_operation = {"type":"interest_operation","value":{"owner":"ikigai","interest":{"amount":"3","precision":3,"nai":"@@000000013"}}}
  fill_vesting_withdraw_operation = {"type":"fill_vesting_withdraw_operation","value":{"from_account":"wolfenstein","to_account":"wolfenstein","withdrawn":{"amount":"1239","precision":6,"nai":"@@000000037"},"deposited":{"amount":"43","precision":3,"nai":"@@000000021"}}}
  fill_order_operation = {"type":"fill_order_operation","value":{"current_owner":"abit","current_orderid":42971,"current_pays":{"amount":"9500","precision":3,"nai":"@@000000013"},"open_owner":"imadev","open_orderid":24,"open_pays":{"amount":"50000","precision":3,"nai":"@@000000021"}}}
  hardfork_operation = {"type":"hardfork_operation","value":{"hardfork_id":3}}
  comment_payout_update_operation = {"type":"comment_payout_update_operation","value":{"author":"nenad-ristic","permlink":"why-we-downvote"}}
  producer_reward_operation = {"type":"producer_reward_operation","value":{"producer":"au1nethyb1","vesting_shares":{"amount":"5236135027","precision":6,"nai":"@@000000037"}}}
  effective_comment_vote_operation = {"type":"effective_comment_vote_operation","value":{"voter":"ams","author":"mauricemikkers","permlink":"re-nenad-ristic-re-mauricemikkers-how-micrography-sparked-my-interest-in-the-evolving-online-drug-trade-20160630t101137843z","weight":"1101429118225888","rshares":251380753,"total_vote_weight":"466779960428791251","pending_payout":{"amount":"34","precision":3,"nai":"@@000000013"}}}
  ineffective_delete_comment_operation = {"type":"ineffective_delete_comment_operation","value":{"author":"jsc","permlink":"re-jsc-voting-20160513t185138004z"}}
  changed_recovery_account_operation = {"type":"changed_recovery_account_operation","value":{"account":"bingo-0","old_recovery_account":"boombastic","new_recovery_account":"boombastic"}}
  transfer_to_vesting_completed_operation = {"type":"transfer_to_vesting_completed_operation","value":{"from_account":"steemit70","to_account":"steemit","hive_vested":{"amount":"100000","precision":3,"nai":"@@000000021"},"vesting_shares_received":{"amount":"100000000","precision":6,"nai":"@@000000037"}}}
  pow_reward_operation = {"type":"pow_reward_operation","value":{"worker":"initminer","reward":{"amount":"0","precision":3,"nai":"@@000000021"}}}
  vesting_shares_split_operation = {"type":"vesting_shares_split_operation","value":{"owner":"terra","vesting_shares_before_split":{"amount":"67667354","precision":6,"nai":"@@000000037"},"vesting_shares_after_split":{"amount":"67667354000000","precision":6,"nai":"@@000000037"}}}
  account_created_operation = {"type":"account_created_operation","value":{"new_account_name":"temp","creator":"","initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"}}}
  system_warning_operation = {"type":"system_warning_operation","value":{"message":"Wrong fee symbol in block 3143833"}}
  limit_order_create2_operation = {"type":"limit_order_create2_operation","value":{"owner":"dez1337","orderid":492991,"amount_to_sell":{"amount":"1","precision":3,"nai":"@@000000013"},"exchange_rate":{"base":{"amount":"1","precision":3,"nai":"@@000000013"},"quote":{"amount":"10","precision":3,"nai":"@@000000021"}},"fill_or_kill":false,"expiration":"2017-05-12T23:11:13"}}
  claim_account_operation = {"type":"claim_account_operation","value":{"creator":"blocktrades","fee":{"amount":"0","precision":3,"nai":"@@000000021"},"extensions":[]}}
  create_claimed_account_operation = {"type":"create_claimed_account_operation","value":{"creator":"blocktrades","new_account_name":"gatherex","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8JH4fTJr73FQimysjmXCEh2UvRwZsG6ftjxsVTmYCeEehZgh25",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6Gp4f7tdDBCu2MV1ZNjUQBw54Nmmmr6axq36qX9sWY7GQQjdY1",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM81yUciDyjJR6jxMRz7oWLR8jmaJchx4tjqt3XmAcWH3xAqbEV3",1]]},"memo_key":"STM7bUBovHJUbsXhkYz9x6JPg36MF7WAsYZKtaudVopBCoJKetuLQ","json_metadata":"{}","extensions":[]}}
  escrow_transfer_operation = {"type":"escrow_transfer_operation","value":{"from":"siol","to":"james","hbd_amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},"escrow_id":23456789,"agent":"fabien","fee":{"amount":"100","precision":3,"nai":"@@000000013"},"json_meta":"{}","ratification_deadline":"2017-02-26T11:22:39","escrow_expiration":"2017-02-28T11:22:39"}}
  escrow_dispute_operation = {"type":"escrow_dispute_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"anonymtest","escrow_id":72526562}}
  escrow_release_operation = {"type":"escrow_release_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"xtar","receiver":"someguy123","escrow_id":72526562,"hbd_amount":{"amount":"5000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"}}}
  escrow_approve_operation = {"type":"escrow_approve_operation","value":{"from":"xtar","to":"testz","agent":"on0tole","who":"on0tole","escrow_id":59102208,"approve":true}}
  transfer_to_savings_operation = {"type":"transfer_to_savings_operation","value":{"from":"abit","to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}
  transfer_from_savings_operation = {"type":"transfer_from_savings_operation","value":{"from":"abit","request_id":101,"to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}
  cancel_transfer_from_savings_operation = {"type":"cancel_transfer_from_savings_operation","value":{"from":"jesta","request_id":1}}
  decline_voting_rights_operation = {"type":"decline_voting_rights_operation","value":{"account":"bilalhaider","decline":true}}
  claim_reward_balance_operation = {"type":"claim_reward_balance_operation","value":{"account":"ocrdu","reward_hive":{"amount":"17","precision":3,"nai":"@@000000021"},"reward_hbd":{"amount":"11","precision":3,"nai":"@@000000013"},"reward_vests":{"amount":"185025103","precision":6,"nai":"@@000000037"}}}
  delegate_vesting_shares_operation = {"type":"delegate_vesting_shares_operation","value":{"delegator":"liberosist","delegatee":"dunia","vesting_shares":{"amount":"94599167138276","precision":6,"nai":"@@000000037"}}}
  account_create_with_delegation_operation = {"type":"account_create_with_delegation_operation","value":{"fee":{"amount":"35000","precision":3,"nai":"@@000000021"},"delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"steem","new_account_name":"hendratayogas","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM51YSoy7MdrAWgeTsQo4xYVR7L4BKucjqDPefsB7ZojBZgU7CCN",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5jgwX1VPT4oZpescjwTmf6k8T8oYmg3RrhjaDnSapis9sFojAL",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5BcLMqLSBXa3DX7ThbbDYFEwcHbvUYWoF8PgTaSVAdNUikBQK1",1]]},"memo_key":"STM5Fj3bNfLCvhFC6U67kfNCg6d8CfpxW2AJRJ9KhELEaoBMK9Ltf","json_metadata":"","extensions":[]}}
  witness_set_properties_operation = {"type":"witness_set_properties_operation","value":{"owner":"holger80","props":[["account_creation_fee","b80b00000000000003535445454d0000"],["key","0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"]],"extensions":[]}}
  account_update2_operation = {"type":"account_update2_operation","value":{"account":"tftest1","json_metadata":"","posting_json_metadata":"{\"profile\":{\"about\":\"Testing account by @travelfeed\",\"couchsurfing\":\"cstest\",\"facebook\":\"facebooktest\",\"instagram\":\"instatest\",\"twitter\":\"twittertest\",\"website\":\"https://test.test\",\"youtube\":\"youtubetest\"}}","extensions":[]}}
  create_proposal_operation = {"type":"create_proposal_operation","value":{"creator":"gtg","receiver":"steem.dao","start_date":"2019-08-27T00:00:00","end_date":"2029-12-31T23:59:59","daily_pay":{"amount":"240000000000","precision":3,"nai":"@@000000013"},"subject":"Return Proposal","permlink":"steemdao","extensions":[]}}
  update_proposal_votes_operation = {"type":"update_proposal_votes_operation","value":{"voter":"gtg","proposal_ids":[0,1],"approve":true,"extensions":[]}}
  remove_proposal_operation = {"type":"remove_proposal_operation","value":{"proposal_owner":"asgarth-dev","proposal_ids":[5],"extensions":[]}}
  update_proposal_operation = {"type":"update_proposal_operation","value":{"proposal_id":139,"creator":"asgarth-dev","daily_pay":{"amount":"999","precision":3,"nai":"@@000000013"},"subject":"Test proposal for DHF related tests","permlink":"test-proposal-for-dhf-related-developments","extensions":[]}}
  collateralized_convert_operation = {"type":"collateralized_convert_operation","value":{"owner":"gandalf","requestid":1625061900,"amount":{"amount":"1000","precision":3,"nai":"@@000000021"}}}
  recurrent_transfer_operation = {"type":"recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","recurrence":24,"executions":5,"extensions":[]}}
  shutdown_witness_operation = {"type":"shutdown_witness_operation","value":{"owner":"mining1"}}
  fill_transfer_from_savings_operation = {"type":"fill_transfer_from_savings_operation","value":{"from":"abit","to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"request_id":101,"memo":""}}
  return_vesting_delegation_operation = {"type":"return_vesting_delegation_operation","value":{"account":"arhag","vesting_shares":{"amount":"1000000000000","precision":6,"nai":"@@000000037"}}}
  comment_benefactor_reward_operation = {"type":"comment_benefactor_reward_operation","value":{"benefactor":"good-karma","author":"abit","permlink":"hard-fork-18-how-to-use-author-reward-splitting-feature","hbd_payout":{"amount":"0","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"0","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"4754505657","precision":6,"nai":"@@000000037"}}}
  clear_null_account_balance_operation = {"type":"clear_null_account_balance_operation","value":{"total_cleared":[{"amount":"2000","precision":3,"nai":"@@000000021"},{"amount":"21702525","precision":3,"nai":"@@000000013"}]}}
  proposal_pay_operation = {"type":"proposal_pay_operation","value":{"proposal_id":0,"receiver":"steem.dao","payer":"steem.dao","payment":{"amount":"157","precision":3,"nai":"@@000000013"},"trx_id":"0000000000000000000000000000000000000000","op_in_trx":0}}
  sps_fund_operation = {"type":"sps_fund_operation","value":{"fund_account":"steem.dao","additional_funds":{"amount":"60","precision":3,"nai":"@@000000013"}}}
  hardfork_hive_operation = {"type":"hardfork_hive_operation","value":{"account":"abduhawab","treasury":"steem.dao","hbd_transferred":{"amount":"6171","precision":3,"nai":"@@000000013"},"hive_transferred":{"amount":"186651","precision":3,"nai":"@@000000021"},"vests_converted":{"amount":"3399458160520","precision":6,"nai":"@@000000037"},"total_hive_from_vests":{"amount":"1735804","precision":3,"nai":"@@000000021"}}}
  hardfork_hive_restore_operation = {"type":"hardfork_hive_restore_operation","value":{"account":"aellly","treasury":"steem.dao","hbd_transferred":{"amount":"3007","precision":3,"nai":"@@000000013"},"hive_transferred":{"amount":"0","precision":3,"nai":"@@000000021"}}}
  delayed_voting_operation = {"type":"delayed_voting_operation","value":{"voter":"balte","votes":"33105558106560"}}
  consolidate_treasury_balance_operation = {"type":"consolidate_treasury_balance_operation","value":{"total_moved":[{"amount":"83353473585","precision":3,"nai":"@@000000021"},{"amount":"560371025","precision":3,"nai":"@@000000013"}]}}
  sps_convert_operation = {"type":"sps_convert_operation","value":{"fund_account":"hive.fund","hive_amount_in":{"amount":"41676736","precision":3,"nai":"@@000000021"},"hbd_amount_out":{"amount":"6543247","precision":3,"nai":"@@000000013"}}}
  fill_collateralized_convert_request_operation = {"type":"fill_collateralized_convert_request_operation","value":{"owner":"gandalf","requestid":1625061900,"amount_in":{"amount":"353","precision":3,"nai":"@@000000021"},"amount_out":{"amount":"103","precision":3,"nai":"@@000000013"},"excess_collateral":{"amount":"647","precision":3,"nai":"@@000000021"}}}
  fill_recurrent_transfer_operation = {"type":"fill_recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","remaining_executions":4}}
  failed_recurrent_transfer_operation = {"type":"failed_recurrent_transfer_operation","value":{"from":"blackknight1423","to":"aa111","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"","consecutive_failures":1,"remaining_executions":0,"deleted":false}}
  limit_order_cancelled_operation = {"type":"limit_order_cancelled_operation","value":{"seller":"linouxis9","amount_back":{"amount":"9950","precision":3,"nai":"@@000000021"}}}

    -- ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{"type":"transfer_operation","value":{"from":"admin","to":"steemit","amount":{"amount":"833000","precision":3,"nai":"@@000000021"},"memo":""}}') ) = 2, 'Incorrect number of impacted accounts';
    -- ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{"type":"escrow_transfer_operation","value":{"from":"xtar","to":"testz","hbd_amount":{"amount":"0","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"1","precision":3,"nai":"@@000000021"},"escrow_id":123456,"agent":"fabien","fee":{"amount":"1","precision":3,"nai":"@@000000021"},"json_meta":"","ratification_deadline":"2017-02-15T15:15:11","escrow_expiration":"2017-02-16T15:15:11"}}') ) = 3, 'Incorrect number of impacted accounts';

    -- --false tests
    -- ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{}') ) = 0, 'Incorrect number of impacted accounts';
    -- ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('') ) = 0, 'Incorrect number of impacted accounts';
    -- ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{BANANA}') ) = 0, 'Incorrect number of impacted accounts';
    -- ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('{') ) = 0, 'Incorrect number of impacted accounts';
    -- ASSERT ( SELECT COUNT(*) FROM hive.get_impacted_accounts('KIWI') ) = 0, 'Incorrect number of impacted accounts';

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
BEGIN
    --Nothing to do
END;
$BODY$
;


