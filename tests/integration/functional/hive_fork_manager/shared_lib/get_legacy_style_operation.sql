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
DECLARE
  vote_operation                                  VARCHAR := '{"type":"vote_operation","value":{"voter":"andzzz","author":"signalandnoise","permlink":"hello-","weight":-10000}}';
  comment_operation                               VARCHAR := '{"type":"comment_operation","value":{"parent_author":"steemit","parent_permlink":"firstpost","author":"admin","permlink":"firstpost","title":"TITLE","body":"First Reply! Lets get this **party** started","json_metadata":"{}"}}';
  transfer_operation                              VARCHAR := '{"type":"transfer_operation","value":{"from":"faddy3","to":"faddy","amount":{"amount":"40000","precision":3,"nai":"@@000000021"},"memo":"this is a test"}}';
  transfer_to_vesting_operation                   VARCHAR := '{"type":"transfer_to_vesting_operation","value":{"from":"steemit70","to":"steemit","amount":{"amount":"100000","precision":3,"nai":"@@000000021"}}}';
  withdraw_vesting_operation                      VARCHAR := '{"type":"withdraw_vesting_operation","value":{"account":"randaletouri","vesting_shares":{"amount":"2753463","precision":6,"nai":"@@000000037"}}}';
  limit_order_create_operation                    VARCHAR := '{"type":"limit_order_create_operation","value":{"owner":"adm","orderid":1,"amount_to_sell":{"amount":"1000","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"1000","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2016-05-31T21:44:00"}}';
  limit_order_cancel_operation                    VARCHAR := '{"type":"limit_order_cancel_operation","value":{"owner":"steempty","orderid":533}}';
  feed_publish_operation                          VARCHAR := '{"type":"feed_publish_operation","value":{"publisher":"abit","exchange_rate":{"base":{"amount":"15000","precision":3,"nai":"@@000000013"},"quote":{"amount":"2000","precision":3,"nai":"@@000000021"}}}}';
  convert_operation                               VARCHAR := '{"type":"convert_operation","value":{"owner":"summon","requestid":1467592168,"amount":{"amount":"5000","precision":3,"nai":"@@000000013"}}}';
  account_create_operation                        VARCHAR := '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"hello","new_account_name":"usd","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5b4i9gBqvh4sbgrooXPu2dbGLewNPZkXeuNeBjyiswnu2szgXx",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7ko5nzqaYfjbD4tKWGmiy3xtT9eQFZ3Pcmq5JmygTRptWSiVQy",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5xAKxnMT2y9VoVJdF63K8xRQAohsiQy9bA33aHeyMB5vgkzaay",1]]},"memo_key":"STM8ZSyzjPm48GmUuMSRufkVYkwYbZzbxeMysAVp7KFQwbTf98TcG","json_metadata":"{}"}}';
  account_update_operation                        VARCHAR := '{"type":"account_update_operation","value":{"account":"theoretical","posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM76EQNV2RTA6yF9TnBvGSV71mW7eW36MM7XQp24JxdoArTfKA76",1]]},"memo_key":"STM6FATHLohxTN8RWWkU9ZZwVywXo6MEDjHHui1jEBYkG2tTdvMYo","json_metadata":""}}';
  witness_update_operation                        VARCHAR := '{"type":"witness_update_operation","value":{"owner":"ihashfury","url":"https://steemit.com/witness-category/@ihashfury/ihashfury-witness-thread","block_signing_key":"STM8aUs6SGoEmNYMd3bYjE1UBr6NQPxGWmTqTdBaxJYSx244edSB2","props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}';
  account_witness_vote_operation                  VARCHAR := '{"type":"account_witness_vote_operation","value":{"account":"steemit","witness":"modprobe","approve":true}}';
  account_witness_proxy_operation                 VARCHAR := '{"type":"account_witness_proxy_operation","value":{"account":"aphrodite","proxy":"datasecuritynode"}}';
  pow_operation                                   VARCHAR := '{"type":"pow_operation","value":{"worker_account":"dark","block_id":"000004433bd4602cf5f74dbb564183837df9cef8","nonce":60,"work":{"worker":"STM5QPFyb4ANmtoaubh4iEtDd1DJvx5jxJYKbFtLExdVjKdGkQo44","input":"fece42ada3ac23101e3c4ee18f6eccc69d6f8710c7b29b496e0a7ad0c128af2c","signature":"2018233fbb20c9a8543604b8edf7ff1ff1bbea22c52a1eabf9592c0316909c4e080d5b4b1ea1a66a7024de10ec3c2b1dbff8c696bfccdee78aca4d560430d33964","work":"0d8423b0fa3d87ed8c3f8dd9c0f79884da8966a1fd1501b27212918f15dfb72e"},"props":{"account_creation_fee":{"amount":"100000","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}';
  custom_operation                                VARCHAR := '{"type":"custom_operation","value":{"required_auths":["bytemaster"],"id":777,"data":"0a627974656d617374657207737465656d697402a3d13897d82114466ad87a74b73a53292d8331d1bd1d3082da6bfbcff19ed097029db013797711c88cccca3692407f9ff9b9ce7221aaa2d797f1692be2215d0a5f607de8b06d3205000ff825a32029a2df80c7cc67d0179fc54d87e4d795f4209b8aeebc93ada0fce7092f92b6d8"}}';
  delete_comment_operation                        VARCHAR := '{"type":"delete_comment_operation","value":{"author":"jsc","permlink":"re-abit-test1-20160606t212217819z"}}';
  custom_json_operation                           VARCHAR := '{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["jsc"],"id":"follow","json":"{\"follower\":\"jsc\",\"following\":\"officialfuzzy\",\"what\":[\"posts\"]}"}}';
  comment_options_operation                       VARCHAR := '{"type":"comment_options_operation","value":{"author":"freebornangel","permlink":"it-s-an-info-war-bad-no-info-you-lose","max_accepted_payout":{"amount":"1000000000","precision":3,"nai":"@@000000013"},"percent_hbd":0,"allow_votes":true,"allow_curation_rewards":true,"extensions":[]}}';
  set_withdraw_vesting_route_operation            VARCHAR := '{"type":"set_withdraw_vesting_route_operation","value":{"from_account":"newyo6","to_account":"newyo","percent":10000,"auto_vest":true}}';
  request_account_recovery_operation              VARCHAR := '{"type":"request_account_recovery_operation","value":{"recovery_account":"steem","account_to_recover":"boatymcboatface","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM61RC4KGbmXNyfk7mmmh2PETAzb4qMm4c5L4maf2oVoAR6aeGJq",1]]},"extensions":[]}}';
  recover_account_operation                       VARCHAR := '{"type":"recover_account_operation","value":{"account_to_recover":"steemychicken1","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM82miH8qam2G2WPPjgyquPBrUbenGDHjhZMxqaKqCugWhcuqZzW",1]]},"recent_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6Wf68LVi22QC9eS8LBWykRiSrKKp5RTWXcNqjh3VPNhiT9xFxx",1]]},"extensions":[]}}';
  change_recovery_account_operation               VARCHAR := '{"type":"change_recovery_account_operation","value":{"account_to_recover":"bingo-0","new_recovery_account":"boombastic","extensions":[]}}';
  pow2_operation                                  VARCHAR := '{"type":"pow2_operation","value":{"work":{"type":"pow2","value":{"input":{"worker_account":"b0y2k31","prev_block":"003ea73c674962ad0e406d6d49736092b43fb385","nonce":"219420911219087363"},"pow_summary":3858814423}},"props":{"account_creation_fee":{"amount":"1","precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000}}}';
  fill_convert_request_operation                  VARCHAR := '{"type":"fill_convert_request_operation","value":{"owner":"summon","requestid":1467592168,"amount_in":{"amount":"5000","precision":3,"nai":"@@000000013"},"amount_out":{"amount":"18867","precision":3,"nai":"@@000000021"}}}';
  author_reward_operation                         VARCHAR := '{"type":"author_reward_operation","value":{"author":"anon","permlink":"that-cool-two-handed-puppet-is-back-with-a-dancing-video","hbd_payout":{"amount":"9","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"0","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"235563374","precision":6,"nai":"@@000000037"},"curators_vesting_payout":{"amount":"455422524","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":false}}';
  curation_reward_operation                       VARCHAR := '{"type":"curation_reward_operation","value":{"curator":"juanlibertad","reward":{"amount":"800915474","precision":6,"nai":"@@000000037"},"comment_author":"chris4210","comment_permlink":"why-brexit-may-not-happen-real-house-of-cards-similarities-to-the-dao","payout_must_be_claimed":false}}';
  comment_reward_operation                        VARCHAR := '{"type":"comment_reward_operation","value":{"author":"ceviche","permlink":"rhubarb-season","payout":{"amount":"938640","precision":3,"nai":"@@000000013"},"author_rewards":2133281,"total_payout_value":{"amount":"469321","precision":3,"nai":"@@000000013"},"curator_payout_value":{"amount":"469318","precision":3,"nai":"@@000000013"},"beneficiary_payout_value":{"amount":"0","precision":3,"nai":"@@000000013"}}}';
  liquidity_reward_operation                      VARCHAR := '{"type":"liquidity_reward_operation","value":{"owner":"adm","payout":{"amount":"1200000","precision":3,"nai":"@@000000021"}}}';
  interest_operation                              VARCHAR := '{"type":"interest_operation","value":{"owner":"ikigai","interest":{"amount":"3","precision":3,"nai":"@@000000013"}}}';
  fill_vesting_withdraw_operation                 VARCHAR := '{"type":"fill_vesting_withdraw_operation","value":{"from_account":"wolfenstein","to_account":"wolfenstein","withdrawn":{"amount":"1239","precision":6,"nai":"@@000000037"},"deposited":{"amount":"43","precision":3,"nai":"@@000000021"}}}';
  fill_order_operation                            VARCHAR := '{"type":"fill_order_operation","value":{"current_owner":"abit","current_orderid":42971,"current_pays":{"amount":"9500","precision":3,"nai":"@@000000013"},"open_owner":"imadev","open_orderid":24,"open_pays":{"amount":"50000","precision":3,"nai":"@@000000021"}}}';
  hardfork_operation                              VARCHAR := '{"type":"hardfork_operation","value":{"hardfork_id":3}}';
  comment_payout_update_operation                 VARCHAR := '{"type":"comment_payout_update_operation","value":{"author":"nenad-ristic","permlink":"why-we-downvote"}}';
  producer_reward_operation                       VARCHAR := '{"type":"producer_reward_operation","value":{"producer":"au1nethyb1","vesting_shares":{"amount":"5236135027","precision":6,"nai":"@@000000037"}}}';
  effective_comment_vote_operation                VARCHAR := '{"type":"effective_comment_vote_operation","value":{"voter":"ams","author":"mauricemikkers","permlink":"re-nenad-ristic-re-mauricemikkers-how-micrography-sparked-my-interest-in-the-evolving-online-drug-trade-20160630t101137843z","weight":"1101429118225888","rshares":251380753,"total_vote_weight":"466779960428791251","pending_payout":{"amount":"34","precision":3,"nai":"@@000000013"}}}';
  ineffective_delete_comment_operation            VARCHAR := '{"type":"ineffective_delete_comment_operation","value":{"author":"jsc","permlink":"re-jsc-voting-20160513t185138004z"}}';
  changed_recovery_account_operation              VARCHAR := '{"type":"changed_recovery_account_operation","value":{"account":"bingo-0","old_recovery_account":"boombastic","new_recovery_account":"boombastic"}}';
  transfer_to_vesting_completed_operation         VARCHAR := '{"type":"transfer_to_vesting_completed_operation","value":{"from_account":"steemit70","to_account":"steemit","hive_vested":{"amount":"100000","precision":3,"nai":"@@000000021"},"vesting_shares_received":{"amount":"100000000","precision":6,"nai":"@@000000037"}}}';
  pow_reward_operation                            VARCHAR := '{"type":"pow_reward_operation","value":{"worker":"initminer","reward":{"amount":"0","precision":3,"nai":"@@000000021"}}}';
  vesting_shares_split_operation                  VARCHAR := '{"type":"vesting_shares_split_operation","value":{"owner":"terra","vesting_shares_before_split":{"amount":"67667354","precision":6,"nai":"@@000000037"},"vesting_shares_after_split":{"amount":"67667354000000","precision":6,"nai":"@@000000037"}}}';
  account_created_operation                       VARCHAR := '{"type":"account_created_operation","value":{"new_account_name":"temp","creator":"","initial_vesting_shares":{"amount":"0","precision":6,"nai":"@@000000037"},"initial_delegation":{"amount":"0","precision":6,"nai":"@@000000037"}}}';
  system_warning_operation                        VARCHAR := '{"type":"system_warning_operation","value":{"message":"Wrong fee symbol in block 3143833"}}';
  limit_order_create2_operation                   VARCHAR := '{"type":"limit_order_create2_operation","value":{"owner":"dez1337","orderid":492991,"amount_to_sell":{"amount":"1","precision":3,"nai":"@@000000013"},"exchange_rate":{"base":{"amount":"1","precision":3,"nai":"@@000000013"},"quote":{"amount":"10","precision":3,"nai":"@@000000021"}},"fill_or_kill":false,"expiration":"2017-05-12T23:11:13"}}';
  claim_account_operation                         VARCHAR := '{"type":"claim_account_operation","value":{"creator":"blocktrades","fee":{"amount":"0","precision":3,"nai":"@@000000021"},"extensions":[]}}';
  create_claimed_account_operation                VARCHAR := '{"type":"create_claimed_account_operation","value":{"creator":"blocktrades","new_account_name":"gatherex","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8JH4fTJr73FQimysjmXCEh2UvRwZsG6ftjxsVTmYCeEehZgh25",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6Gp4f7tdDBCu2MV1ZNjUQBw54Nmmmr6axq36qX9sWY7GQQjdY1",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM81yUciDyjJR6jxMRz7oWLR8jmaJchx4tjqt3XmAcWH3xAqbEV3",1]]},"memo_key":"STM7bUBovHJUbsXhkYz9x6JPg36MF7WAsYZKtaudVopBCoJKetuLQ","json_metadata":"{}","extensions":[]}}';
  escrow_transfer_operation                       VARCHAR := '{"type":"escrow_transfer_operation","value":{"from":"siol","to":"james","hbd_amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},"escrow_id":23456789,"agent":"fabien","fee":{"amount":"100","precision":3,"nai":"@@000000013"},"json_meta":"{}","ratification_deadline":"2017-02-26T11:22:39","escrow_expiration":"2017-02-28T11:22:39"}}';
  escrow_dispute_operation                        VARCHAR := '{"type":"escrow_dispute_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"anonymtest","escrow_id":72526562}}';
  escrow_release_operation                        VARCHAR := '{"type":"escrow_release_operation","value":{"from":"anonymtest","to":"someguy123","agent":"xtar","who":"xtar","receiver":"someguy123","escrow_id":72526562,"hbd_amount":{"amount":"5000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"}}}';
  escrow_approve_operation                        VARCHAR := '{"type":"escrow_approve_operation","value":{"from":"xtar","to":"testz","agent":"on0tole","who":"on0tole","escrow_id":59102208,"approve":true}}';
  transfer_to_savings_operation                   VARCHAR := '{"type":"transfer_to_savings_operation","value":{"from":"abit","to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}';
  transfer_from_savings_operation                 VARCHAR := '{"type":"transfer_from_savings_operation","value":{"from":"abit","request_id":101,"to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"memo":""}}';
  cancel_transfer_from_savings_operation          VARCHAR := '{"type":"cancel_transfer_from_savings_operation","value":{"from":"jesta","request_id":1}}';
  decline_voting_rights_operation                 VARCHAR := '{"type":"decline_voting_rights_operation","value":{"account":"bilalhaider","decline":true}}';
  claim_reward_balance_operation                  VARCHAR := '{"type":"claim_reward_balance_operation","value":{"account":"ocrdu","reward_hive":{"amount":"17","precision":3,"nai":"@@000000021"},"reward_hbd":{"amount":"11","precision":3,"nai":"@@000000013"},"reward_vests":{"amount":"185025103","precision":6,"nai":"@@000000037"}}}';
  delegate_vesting_shares_operation               VARCHAR := '{"type":"delegate_vesting_shares_operation","value":{"delegator":"liberosist","delegatee":"dunia","vesting_shares":{"amount":"94599167138276","precision":6,"nai":"@@000000037"}}}';
  account_create_with_delegation_operation        VARCHAR := '{"type":"account_create_with_delegation_operation","value":{"fee":{"amount":"35000","precision":3,"nai":"@@000000021"},"delegation":{"amount":"0","precision":6,"nai":"@@000000037"},"creator":"steem","new_account_name":"hendratayogas","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM51YSoy7MdrAWgeTsQo4xYVR7L4BKucjqDPefsB7ZojBZgU7CCN",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5jgwX1VPT4oZpescjwTmf6k8T8oYmg3RrhjaDnSapis9sFojAL",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5BcLMqLSBXa3DX7ThbbDYFEwcHbvUYWoF8PgTaSVAdNUikBQK1",1]]},"memo_key":"STM5Fj3bNfLCvhFC6U67kfNCg6d8CfpxW2AJRJ9KhELEaoBMK9Ltf","json_metadata":"","extensions":[]}}';
  witness_set_properties_operation                VARCHAR := '{"type":"witness_set_properties_operation","value":{"owner":"holger80","props":[["account_creation_fee","b80b00000000000003535445454d0000"],["key","0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"]],"extensions":[]}}';
  account_update2_operation                       VARCHAR := '{"type":"account_update2_operation","value":{"account":"tftest1","json_metadata":"","posting_json_metadata":"{\"profile\":{\"about\":\"Testing account by @travelfeed\",\"couchsurfing\":\"cstest\",\"facebook\":\"facebooktest\",\"instagram\":\"instatest\",\"twitter\":\"twittertest\",\"website\":\"https://test.test\",\"youtube\":\"youtubetest\"}}","extensions":[]}}';
  create_proposal_operation                       VARCHAR := '{"type":"create_proposal_operation","value":{"creator":"gtg","receiver":"steem.dao","start_date":"2019-08-27T00:00:00","end_date":"2029-12-31T23:59:59","daily_pay":{"amount":"240000000000","precision":3,"nai":"@@000000013"},"subject":"Return Proposal","permlink":"steemdao","extensions":[]}}';
  update_proposal_votes_operation                 VARCHAR := '{"type":"update_proposal_votes_operation","value":{"voter":"gtg","proposal_ids":[0,1],"approve":true,"extensions":[]}}';
  remove_proposal_operation                       VARCHAR := '{"type":"remove_proposal_operation","value":{"proposal_owner":"asgarth-dev","proposal_ids":[5],"extensions":[]}}';
  update_proposal_operation                       VARCHAR := '{"type":"update_proposal_operation","value":{"proposal_id":139,"creator":"asgarth-dev","daily_pay":{"amount":"999","precision":3,"nai":"@@000000013"},"subject":"Test proposal for DHF related tests","permlink":"test-proposal-for-dhf-related-developments","extensions":[]}}';
  collateralized_convert_operation                VARCHAR := '{"type":"collateralized_convert_operation","value":{"owner":"gandalf","requestid":1625061900,"amount":{"amount":"1000","precision":3,"nai":"@@000000021"}}}';
  recurrent_transfer_operation                    VARCHAR := '{"type":"recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","recurrence":24,"executions":5,"extensions":[]}}';
  shutdown_witness_operation                      VARCHAR := '{"type":"shutdown_witness_operation","value":{"owner":"mining1"}}';
  fill_transfer_from_savings_operation            VARCHAR := '{"type":"fill_transfer_from_savings_operation","value":{"from":"abit","to":"abit","amount":{"amount":"1000","precision":3,"nai":"@@000000013"},"request_id":101,"memo":""}}';
  return_vesting_delegation_operation             VARCHAR := '{"type":"return_vesting_delegation_operation","value":{"account":"arhag","vesting_shares":{"amount":"1000000000000","precision":6,"nai":"@@000000037"}}}';
  comment_benefactor_reward_operation             VARCHAR := '{"type":"comment_benefactor_reward_operation","value":{"benefactor":"good-karma","author":"abit","permlink":"hard-fork-18-how-to-use-author-reward-splitting-feature","hbd_payout":{"amount":"0","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"0","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"4754505657","precision":6,"nai":"@@000000037"}}}';
  clear_null_account_balance_operation            VARCHAR := '{"type":"clear_null_account_balance_operation","value":{"total_cleared":[{"amount":"2000","precision":3,"nai":"@@000000021"},{"amount":"21702525","precision":3,"nai":"@@000000013"}]}}';
  proposal_pay_operation                          VARCHAR := '{"type":"proposal_pay_operation","value":{"proposal_id":0,"receiver":"steem.dao","payer":"steem.dao","payment":{"amount":"157","precision":3,"nai":"@@000000013"},"trx_id":"0000000000000000000000000000000000000000","op_in_trx":0}}';
  dhf_funding_operation                           VARCHAR := '{"type":"dhf_funding_operation","value":{"fund_account":"steem.dao","additional_funds":{"amount":"60","precision":3,"nai":"@@000000013"}}}';
  hardfork_hive_operation                         VARCHAR := '{"type":"hardfork_hive_operation","value":{"account":"abduhawab","treasury":"steem.dao","hbd_transferred":{"amount":"6171","precision":3,"nai":"@@000000013"},"hive_transferred":{"amount":"186651","precision":3,"nai":"@@000000021"},"vests_converted":{"amount":"3399458160520","precision":6,"nai":"@@000000037"},"total_hive_from_vests":{"amount":"1735804","precision":3,"nai":"@@000000021"}}}';
  hardfork_hive_restore_operation                 VARCHAR := '{"type":"hardfork_hive_restore_operation","value":{"account":"aellly","treasury":"steem.dao","hbd_transferred":{"amount":"3007","precision":3,"nai":"@@000000013"},"hive_transferred":{"amount":"0","precision":3,"nai":"@@000000021"}}}';
  delayed_voting_operation                        VARCHAR := '{"type":"delayed_voting_operation","value":{"voter":"balte","votes":"33105558106560"}}';
  consolidate_treasury_balance_operation          VARCHAR := '{"type":"consolidate_treasury_balance_operation","value":{"total_moved":[{"amount":"83353473585","precision":3,"nai":"@@000000021"},{"amount":"560371025","precision":3,"nai":"@@000000013"}]}}';
  dhf_conversion_operation                        VARCHAR := '{"type":"dhf_conversion_operation","value":{"fund_account":"hive.fund","hive_amount_in":{"amount":"41676736","precision":3,"nai":"@@000000021"},"hbd_amount_out":{"amount":"6543247","precision":3,"nai":"@@000000013"}}}';
  fill_collateralized_convert_request_operation   VARCHAR := '{"type":"fill_collateralized_convert_request_operation","value":{"owner":"gandalf","requestid":1625061900,"amount_in":{"amount":"353","precision":3,"nai":"@@000000021"},"amount_out":{"amount":"103","precision":3,"nai":"@@000000013"},"excess_collateral":{"amount":"647","precision":3,"nai":"@@000000021"}}}';
  fill_recurrent_transfer_operation               VARCHAR := '{"type":"fill_recurrent_transfer_operation","value":{"from":"deathwing","to":"rishi556","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"test","remaining_executions":4}}';
  failed_recurrent_transfer_operation             VARCHAR := '{"type":"failed_recurrent_transfer_operation","value":{"from":"blackknight1423","to":"aa111","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"","consecutive_failures":1,"remaining_executions":0,"deleted":false}}';
  limit_order_cancelled_operation                 VARCHAR := '{"type":"limit_order_cancelled_operation","value":{"seller":"linouxis9","amount_back":{"amount":"9950","precision":3,"nai":"@@000000021"}}}';
  expired_account_notification_operation          VARCHAR := '{"type":"expired_account_notification_operation","value":{"account":"abit"}}';

BEGIN

  ASSERT (SELECT hive.get_legacy_style_operation(vote_operation)->>0) = 'vote', 'operation "vote_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)->>0) = 'comment', 'operation "comment_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)#>>'{1,parent_author}') = 'steemit', 'operation "comment_operation/parent_author" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)#>>'{1,parent_permlink}') = 'firstpost', 'operation "comment_operation/parent_permlink" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)#>>'{1,author}') = 'admin', 'operation "comment_operation/author" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)#>>'{1,permlink}') = 'firstpost', 'operation "comment_operation/permlink" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)#>>'{1,title}') = 'TITLE', 'operation "comment_operation/title" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)#>>'{1,body}') = 'First Reply! Lets get this **party** started', 'operation "comment_operation/body" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_operation)#>>'{1,json_metadata}') = '{}', 'operation "comment_operation/json_metadata" error';
  ASSERT ((SELECT hive.get_legacy_style_operation(comment_operation)::VARCHAR) = '["comment",{"parent_author":"steemit","parent_permlink":"firstpost","author":"admin","permlink":"firstpost","title":"TITLE","body":"First Reply! Lets get this **party** started","json_metadata":"{}"}]'), 'operation "comment_operation/whole-body" error';

  ASSERT (SELECT hive.get_legacy_style_operation(transfer_operation)->>0) = 'transfer', 'operation "transfer_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_operation)#>>'{1,from}') = 'faddy3', 'operation "transfer_operation/from" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_operation)#>>'{1,to}') = 'faddy', 'operation "transfer_operation/to" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_operation)#>>'{1,amount}') = '40.000 HIVE', 'operation "transfer_operation/amount" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_operation)#>>'{1,memo}') = 'this is a test', 'operation "transfer_operation/memo" error';
  ASSERT ((SELECT hive.get_legacy_style_operation(transfer_operation)::VARCHAR) = '["transfer",{"from":"faddy3","to":"faddy","amount":"40.000 HIVE","memo":"this is a test"}]'), 'operation "transfer_operation/whole-body" error';

  ASSERT (SELECT hive.get_legacy_style_operation(transfer_to_vesting_operation)->>0) = 'transfer_to_vesting', 'operation "transfer_to_vesting_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_to_vesting_operation)#>>'{1,amount}') = '100.000 HIVE', 'operation "transfer_to_vesting_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(withdraw_vesting_operation)->>0) = 'withdraw_vesting', 'operation "withdraw_vesting_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(withdraw_vesting_operation)#>>'{1,vesting_shares}') = '2.753463 VESTS', 'operation "withdraw_vesting_operation/vesting_shares" error';

  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_create_operation)->>0) = 'limit_order_create', 'operation "limit_order_create_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_create_operation)#>>'{1,amount_to_sell}') = '1.000 HIVE', 'operation "limit_order_create_operation/amount_to_sell" error';
  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_create_operation)#>>'{1,min_to_receive}') = '1.000 HBD', 'operation "limit_order_create_operation/min_to_receive" error';

  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_cancel_operation)->>0) = 'limit_order_cancel', 'operation "limit_order_cancel_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(feed_publish_operation)->>0) = 'feed_publish', 'operation "feed_publish_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(feed_publish_operation)#>>'{1,exchange_rate,base}') = '15.000 HBD', 'operation "feed_publish_operation/exchange_rate/base" error';
  ASSERT (SELECT hive.get_legacy_style_operation(feed_publish_operation)#>>'{1,exchange_rate,quote}') = '2.000 HIVE', 'operation "feed_publish_operation/exchange_rate/quote" error';

  ASSERT (SELECT hive.get_legacy_style_operation(convert_operation)->>0) = 'convert', 'operation "convert_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(convert_operation)#>>'{1,amount}') = '5.000 HBD', 'operation "convert_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(account_create_operation)->>0) = 'account_create', 'operation "account_create_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(account_create_operation)#>>'{1,fee}') = '0.000 HIVE', 'operation "account_create_operation/fee" error';

  ASSERT (SELECT hive.get_legacy_style_operation(account_update_operation)->>0) = 'account_update', 'operation "account_update_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(witness_update_operation)->>0) = 'witness_update', 'operation "witness_update_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(witness_update_operation)#>>'{1,props,account_creation_fee}') = '100.000 HIVE', 'operation "witness_update_operation/props/account_creation_fee" error';
  ASSERT (SELECT hive.get_legacy_style_operation(witness_update_operation)#>>'{1,fee}') = '0.000 HIVE', 'operation "witness_update_operation/fee" error';

  ASSERT (SELECT hive.get_legacy_style_operation(account_witness_vote_operation)->>0) = 'account_witness_vote', 'operation "account_witness_vote_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(account_witness_proxy_operation)->>0) = 'account_witness_proxy', 'operation "account_witness_proxy_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(pow_operation)->>0) = 'pow', 'operation "pow_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(custom_operation)->>0) = 'custom', 'operation "custom_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(delete_comment_operation)->>0) = 'delete_comment', 'operation "delete_comment_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(custom_json_operation)->>0) = 'custom_json', 'operation "custom_json_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(comment_options_operation)->>0) = 'comment_options', 'operation "comment_options_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_options_operation)#>>'{1,max_accepted_payout}') = '1000000.000 HBD', 'operation "comment_options_operation/max_accepted_payout" error';

  ASSERT (SELECT hive.get_legacy_style_operation(set_withdraw_vesting_route_operation)->>0) = 'set_withdraw_vesting_route', 'operation "set_withdraw_vesting_route_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(request_account_recovery_operation)->>0) = 'request_account_recovery', 'operation "request_account_recovery_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(recover_account_operation)->>0) = 'recover_account', 'operation "recover_account_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(change_recovery_account_operation)->>0) = 'change_recovery_account', 'operation "change_recovery_account_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(pow2_operation)->>0) = 'pow2', 'operation "pow2_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(pow2_operation)#>>'{1,props,account_creation_fee}') = '0.001 HIVE', 'operation "pow2_operation/props/account_creation_fee" error';

  ASSERT (SELECT hive.get_legacy_style_operation(fill_convert_request_operation)->>0) = 'fill_convert_request', 'operation "fill_convert_request_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_convert_request_operation)#>>'{1,amount_in}') = '5.000 HBD', 'operation "fill_convert_request_operation/amount_in" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_convert_request_operation)#>>'{1,amount_out}') = '18.867 HIVE', 'operation "fill_convert_request_operation/amount_out" error';

  ASSERT (SELECT hive.get_legacy_style_operation(author_reward_operation)->>0) = 'author_reward', 'operation "author_reward_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(author_reward_operation)#>>'{1,hbd_payout}') = '0.009 HBD', 'operation "author_reward_operation/hbd_payout" error';
  ASSERT (SELECT hive.get_legacy_style_operation(author_reward_operation)#>>'{1,hive_payout}') = '0.000 HIVE', 'operation "author_reward_operation/hive_payout" error';
  ASSERT (SELECT hive.get_legacy_style_operation(author_reward_operation)#>>'{1,vesting_payout}') = '235.563374 VESTS', 'operation "author_reward_operation/vesting_payout" error';
  ASSERT (SELECT hive.get_legacy_style_operation(author_reward_operation)#>>'{1,curators_vesting_payout}') = '455.422524 VESTS', 'operation "author_reward_operation/curators_vesting_payout" error';

  ASSERT (SELECT hive.get_legacy_style_operation(curation_reward_operation)->>0) = 'curation_reward', 'operation "curation_reward_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(curation_reward_operation)#>>'{1,reward}') = '800.915474 VESTS', 'operation "curation_reward_operation/reward" error';

  ASSERT (SELECT hive.get_legacy_style_operation(comment_reward_operation)->>0) = 'comment_reward', 'operation "comment_reward_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_reward_operation)#>>'{1,payout}') = '938.640 HBD', 'operation "comment_reward_operation/payout" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_reward_operation)#>>'{1,total_payout_value}') = '469.321 HBD', 'operation "comment_reward_operation/total_payout_value" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_reward_operation)#>>'{1,curator_payout_value}') = '469.318 HBD', 'operation "comment_reward_operation/curator_payout_value" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_reward_operation)#>>'{1,beneficiary_payout_value}') = '0.000 HBD', 'operation "comment_reward_operation/beneficiary_payout_value" error';

  ASSERT (SELECT hive.get_legacy_style_operation(liquidity_reward_operation)->>0) = 'liquidity_reward', 'operation "liquidity_reward_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(liquidity_reward_operation)#>>'{1,payout}') = '1200.000 HIVE', 'operation "liquidity_reward_operation/payout" error';

  ASSERT (SELECT hive.get_legacy_style_operation(interest_operation)->>0) = 'interest', 'operation "interest_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(interest_operation)#>>'{1,interest}') = '0.003 HBD', 'operation "interest_operation/interest" error';

  ASSERT (SELECT hive.get_legacy_style_operation(fill_vesting_withdraw_operation)->>0) = 'fill_vesting_withdraw', 'operation "fill_vesting_withdraw_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_vesting_withdraw_operation)#>>'{1,withdrawn}') = '0.001239 VESTS', 'operation "fill_vesting_withdraw_operation/withdrawn" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_vesting_withdraw_operation)#>>'{1,deposited}') = '0.043 HIVE', 'operation "fill_vesting_withdraw_operation/deposited" error';

  ASSERT (SELECT hive.get_legacy_style_operation(fill_order_operation)->>0) = 'fill_order', 'operation "fill_order_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_order_operation)#>>'{1,current_pays}') = '9.500 HBD', 'operation "fill_order_operation/current_pays" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_order_operation)#>>'{1,open_pays}') = '50.000 HIVE', 'operation "fill_order_operation/open_pays" error';

  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_operation)->>0) = 'hardfork', 'operation "hardfork_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_payout_update_operation)->>0) = 'comment_payout_update', 'operation "comment_payout_update_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(producer_reward_operation)->>0) = 'producer_reward', 'operation "producer_reward_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(producer_reward_operation)#>>'{1,vesting_shares}') = '5236.135027 VESTS', 'operation "producer_reward_operation/vesting_shares" error';

  ASSERT (SELECT hive.get_legacy_style_operation(effective_comment_vote_operation)->>0) = 'effective_comment_vote', 'operation "effective_comment_vote_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(effective_comment_vote_operation)#>>'{1,pending_payout}') = '0.034 HBD', 'operation "effective_comment_vote_operation/pending_payout" error';

  ASSERT (SELECT hive.get_legacy_style_operation(ineffective_delete_comment_operation)->>0) = 'ineffective_delete_comment', 'operation "ineffective_delete_comment_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(changed_recovery_account_operation)->>0) = 'changed_recovery_account', 'operation "changed_recovery_account_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(transfer_to_vesting_completed_operation)->>0) = 'transfer_to_vesting_completed', 'operation "transfer_to_vesting_completed_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_to_vesting_completed_operation)#>>'{1,hive_vested}') = '100.000 HIVE', 'operation "transfer_to_vesting_completed_operation/hive_vested" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_to_vesting_completed_operation)#>>'{1,vesting_shares_received}') = '100.000000 VESTS', 'operation "transfer_to_vesting_completed_operation/vesting_shares_received" error';

  ASSERT (SELECT hive.get_legacy_style_operation(pow_reward_operation)->>0) = 'pow_reward', 'operation "pow_reward_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(pow_reward_operation)#>>'{1,reward}') = '0.000 HIVE', 'operation "pow_reward_operation/reward" error';

  ASSERT (SELECT hive.get_legacy_style_operation(vesting_shares_split_operation)->>0) = 'vesting_shares_split', 'operation "vesting_shares_split_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(vesting_shares_split_operation)#>>'{1,vesting_shares_before_split}') = '67.667354 VESTS', 'operation "vesting_shares_split_operation/vesting_shares_before_split" error';
  ASSERT (SELECT hive.get_legacy_style_operation(vesting_shares_split_operation)#>>'{1,vesting_shares_after_split}') = '67667354.000000 VESTS', 'operation "vesting_shares_split_operation/vesting_shares_after_split" error';

  ASSERT (SELECT hive.get_legacy_style_operation(account_created_operation)->>0) = 'account_created', 'operation "account_created_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(account_created_operation)#>>'{1,initial_vesting_shares}') = '0.000000 VESTS', 'operation "account_created_operation/initial_vesting_shares" error';
  ASSERT (SELECT hive.get_legacy_style_operation(account_created_operation)#>>'{1,initial_delegation}') = '0.000000 VESTS', 'operation "account_created_operation/initial_delegation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(system_warning_operation)->>0) = 'system_warning', 'operation "system_warning_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_create2_operation)->>0) = 'limit_order_create2', 'operation "limit_order_create2_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_create2_operation)#>>'{1,amount_to_sell}') = '0.001 HBD', 'operation "limit_order_create2_operation/amount_to_sell" error';
  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_create2_operation)#>>'{1,exchange_rate,base}') = '0.001 HBD', 'operation "limit_order_create2_operation/exchange_rate/base" error';
  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_create2_operation)#>>'{1,exchange_rate,quote}') = '0.010 HIVE', 'operation "limit_order_create2_operation/exchange_rate/quote" error';

  ASSERT (SELECT hive.get_legacy_style_operation(claim_account_operation)->>0) = 'claim_account', 'operation "claim_account_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(claim_account_operation)#>>'{1,fee}') = '0.000 HIVE', 'operation "claim_account_operation/fee" error';

  ASSERT (SELECT hive.get_legacy_style_operation(create_claimed_account_operation)->>0) = 'create_claimed_account', 'operation "create_claimed_account_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(escrow_transfer_operation)->>0) = 'escrow_transfer', 'operation "escrow_transfer_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(escrow_transfer_operation)#>>'{1,hbd_amount}') = '1.000 HBD', 'operation "escrow_transfer_operation/hbd_amount" error';
  ASSERT (SELECT hive.get_legacy_style_operation(escrow_transfer_operation)#>>'{1,hive_amount}') = '0.000 HIVE', 'operation "escrow_transfer_operation/hive_amount" error';
  ASSERT (SELECT hive.get_legacy_style_operation(escrow_transfer_operation)#>>'{1,fee}') = '0.100 HBD', 'operation "escrow_transfer_operation/fee" error';

  ASSERT (SELECT hive.get_legacy_style_operation(escrow_dispute_operation)->>0) = 'escrow_dispute', 'operation "escrow_dispute_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(escrow_release_operation)->>0) = 'escrow_release', 'operation "escrow_release_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(escrow_release_operation)#>>'{1,hbd_amount}') = '5.000 HBD', 'operation "escrow_release_operation/hbd_amount" error';
  ASSERT (SELECT hive.get_legacy_style_operation(escrow_release_operation)#>>'{1,hive_amount}') = '0.000 HIVE', 'operation "escrow_release_operation/hive_amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(escrow_approve_operation)->>0) = 'escrow_approve', 'operation "escrow_approve_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(transfer_to_savings_operation)->>0) = 'transfer_to_savings', 'operation "transfer_to_savings_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_to_savings_operation)#>>'{1,amount}') = '1.000 HBD', 'operation "transfer_to_savings_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(transfer_from_savings_operation)->>0) = 'transfer_from_savings', 'operation "transfer_from_savings_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(transfer_from_savings_operation)#>>'{1,amount}') = '1.000 HBD', 'operation "transfer_from_savings_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(cancel_transfer_from_savings_operation)->>0) = 'cancel_transfer_from_savings', 'operation "cancel_transfer_from_savings_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(decline_voting_rights_operation)->>0) = 'decline_voting_rights', 'operation "decline_voting_rights_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(claim_reward_balance_operation)->>0) = 'claim_reward_balance', 'operation "claim_reward_balance_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(claim_reward_balance_operation)#>>'{1,reward_hive}') = '0.017 HIVE', 'operation "claim_reward_balance_operation/reward_hive" error';
  ASSERT (SELECT hive.get_legacy_style_operation(claim_reward_balance_operation)#>>'{1,reward_hbd}') = '0.011 HBD', 'operation "claim_reward_balance_operation/reward_hbd" error';
  ASSERT (SELECT hive.get_legacy_style_operation(claim_reward_balance_operation)#>>'{1,reward_vests}') = '185.025103 VESTS', 'operation "claim_reward_balance_operation/reward_vests" error';

  ASSERT (SELECT hive.get_legacy_style_operation(delegate_vesting_shares_operation)->>0) = 'delegate_vesting_shares', 'operation "delegate_vesting_shares_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(delegate_vesting_shares_operation)#>>'{1,vesting_shares}') = '94599167.138276 VESTS', 'operation "delegate_vesting_shares_operation/vesting_shares" error';

  ASSERT (SELECT hive.get_legacy_style_operation(account_create_with_delegation_operation)->>0) = 'account_create_with_delegation', 'operation "account_create_with_delegation_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(account_create_with_delegation_operation)#>>'{1,fee}') = '35.000 HIVE', 'operation "account_create_with_delegation_operation/fee" error';
  ASSERT (SELECT hive.get_legacy_style_operation(account_create_with_delegation_operation)#>>'{1,delegation}') = '0.000000 VESTS', 'operation "account_create_with_delegation_operation/delegation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(witness_set_properties_operation)->>0) = 'witness_set_properties', 'operation "witness_set_properties_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(account_update2_operation)->>0) = 'account_update2', 'operation "account_update2_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(create_proposal_operation)->>0) = 'create_proposal', 'operation "create_proposal_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(create_proposal_operation)#>>'{1,daily_pay}') = '240000000.000 HBD', 'operation "create_proposal_operation/daily_pay" error';

  ASSERT (SELECT hive.get_legacy_style_operation(update_proposal_votes_operation)->>0) = 'update_proposal_votes', 'operation "update_proposal_votes_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(remove_proposal_operation)->>0) = 'remove_proposal', 'operation "remove_proposal_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(update_proposal_operation)->>0) = 'update_proposal', 'operation "update_proposal_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(update_proposal_operation)#>>'{1,daily_pay}') = '0.999 HBD', 'operation "update_proposal_operation/daily_pay" error';

  ASSERT (SELECT hive.get_legacy_style_operation(collateralized_convert_operation)->>0) = 'collateralized_convert', 'operation "collateralized_convert_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(collateralized_convert_operation)#>>'{1,amount}') = '1.000 HIVE', 'operation "collateralized_convert_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(recurrent_transfer_operation)->>0) = 'recurrent_transfer', 'operation "recurrent_transfer_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(recurrent_transfer_operation)#>>'{1,amount}') = '1.000 HIVE', 'operation "recurrent_transfer_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(shutdown_witness_operation)->>0) = 'shutdown_witness', 'operation "shutdown_witness_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(fill_transfer_from_savings_operation)->>0) = 'fill_transfer_from_savings', 'operation "fill_transfer_from_savings_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_transfer_from_savings_operation)#>>'{1,amount}') = '1.000 HBD', 'operation "fill_transfer_from_savings_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(return_vesting_delegation_operation)->>0) = 'return_vesting_delegation', 'operation "return_vesting_delegation_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(return_vesting_delegation_operation)#>>'{1,vesting_shares}') = '1000000.000000 VESTS', 'operation "return_vesting_delegation_operation/vesting_shares" error';

  ASSERT (SELECT hive.get_legacy_style_operation(comment_benefactor_reward_operation)->>0) = 'comment_benefactor_reward', 'operation "comment_benefactor_reward_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_benefactor_reward_operation)#>>'{1,hbd_payout}') = '0.000 HBD', 'operation "comment_benefactor_reward_operation/hbd_payout" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_benefactor_reward_operation)#>>'{1,hive_payout}') = '0.000 HIVE', 'operation "comment_benefactor_reward_operation/hive_payout" error';
  ASSERT (SELECT hive.get_legacy_style_operation(comment_benefactor_reward_operation)#>>'{1,vesting_payout}') = '4754.505657 VESTS', 'operation "comment_benefactor_reward_operation/vesting_payout" error';

  ASSERT (SELECT hive.get_legacy_style_operation(clear_null_account_balance_operation)->>0) = 'clear_null_account_balance', 'operation "clear_null_account_balance_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(clear_null_account_balance_operation)#>>'{1,total_cleared,0}') = '2.000 HIVE', 'operation "clear_null_account_balance_operation/total_cleared/0" error';
  ASSERT (SELECT hive.get_legacy_style_operation(clear_null_account_balance_operation)#>>'{1,total_cleared,1}') = '21702.525 HBD', 'operation "clear_null_account_balance_operation/total_cleared/1" error';

  ASSERT (SELECT hive.get_legacy_style_operation(proposal_pay_operation)->>0) = 'proposal_pay', 'operation "proposal_pay_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(proposal_pay_operation)#>>'{1,payment}') = '0.157 HBD', 'operation "proposal_pay_operation/payment" error';

  ASSERT (SELECT hive.get_legacy_style_operation(dhf_funding_operation)->>0) = 'dhf_funding', 'operation "dhf_funding_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(dhf_funding_operation)#>>'{1,additional_funds}') = '0.060 HBD', 'operation "dhf_funding_operation/additional_funds" error';

  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_operation)->>0) = 'hardfork_hive', 'operation "hardfork_hive_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_operation)#>>'{1,hbd_transferred}') = '6.171 HBD', 'operation "hardfork_hive_operation/hbd_transferred" error';
  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_operation)#>>'{1,hive_transferred}') = '186.651 HIVE', 'operation "hardfork_hive_operation/hive_transferred" error';
  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_operation)#>>'{1,vests_converted}') = '3399458.160520 VESTS', 'operation "hardfork_hive_operation/vests_converted" error';
  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_operation)#>>'{1,total_hive_from_vests}') = '1735.804 HIVE', 'operation "hardfork_hive_operation/total_hive_from_vests" error';

  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_restore_operation)->>0) = 'hardfork_hive_restore', 'operation "hardfork_hive_restore_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_restore_operation)#>>'{1,hbd_transferred}') = '3.007 HBD', 'operation "hardfork_hive_restore_operation/hbd_transferred" error';
  ASSERT (SELECT hive.get_legacy_style_operation(hardfork_hive_restore_operation)#>>'{1,hive_transferred}') = '0.000 HIVE', 'operation "hardfork_hive_restore_operation/hive_transferred" error';

  ASSERT (SELECT hive.get_legacy_style_operation(delayed_voting_operation)->>0) = 'delayed_voting', 'operation "delayed_voting_operation" error';

  ASSERT (SELECT hive.get_legacy_style_operation(consolidate_treasury_balance_operation)->>0) = 'consolidate_treasury_balance', 'operation "consolidate_treasury_balance_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(consolidate_treasury_balance_operation)#>>'{1,total_moved,0}') = '83353473.585 HIVE', 'operation "consolidate_treasury_balance_operation/total_moved/0" error';
  ASSERT (SELECT hive.get_legacy_style_operation(consolidate_treasury_balance_operation)#>>'{1,total_moved,1}') = '560371.025 HBD', 'operation "consolidate_treasury_balance_operation/total_moved/1" error';

  ASSERT (SELECT hive.get_legacy_style_operation(dhf_conversion_operation)->>0) = 'dhf_conversion', 'operation "dhf_conversion_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(dhf_conversion_operation)#>>'{1,hive_amount_in}') = '41676.736 HIVE', 'operation "dhf_conversion_operation/hive_amount_in" error';
  ASSERT (SELECT hive.get_legacy_style_operation(dhf_conversion_operation)#>>'{1,hbd_amount_out}') = '6543.247 HBD', 'operation "dhf_conversion_operation/hbd_amount_out" error';

  ASSERT (SELECT hive.get_legacy_style_operation(fill_collateralized_convert_request_operation)->>0) = 'fill_collateralized_convert_request', 'operation "fill_collateralized_convert_request_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_collateralized_convert_request_operation)#>>'{1,amount_in}') = '0.353 HIVE', 'operation "fill_collateralized_convert_request_operation/amount_in" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_collateralized_convert_request_operation)#>>'{1,amount_out}') = '0.103 HBD', 'operation "fill_collateralized_convert_request_operation/amount_out" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_collateralized_convert_request_operation)#>>'{1,excess_collateral}') = '0.647 HIVE', 'operation "fill_collateralized_convert_request_operation/excess_collateral" error';

  ASSERT (SELECT hive.get_legacy_style_operation(fill_recurrent_transfer_operation)->>0) = 'fill_recurrent_transfer', 'operation "fill_recurrent_transfer_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(fill_recurrent_transfer_operation)#>>'{1,amount}') = '1.000 HIVE', 'operation "fill_recurrent_transfer_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(failed_recurrent_transfer_operation)->>0) = 'failed_recurrent_transfer', 'operation "failed_recurrent_transfer_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(failed_recurrent_transfer_operation)#>>'{1,amount}') = '1.000 HIVE', 'operation "failed_recurrent_transfer_operation/amount" error';

  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_cancelled_operation)->>0) = 'limit_order_cancelled', 'operation "limit_order_cancelled_operation" error';
  ASSERT (SELECT hive.get_legacy_style_operation(limit_order_cancelled_operation)#>>'{1,amount_back}') = '9.950 HIVE', 'operation "limit_order_cancelled_operation/amount_back" error';

  ASSERT (SELECT hive.get_legacy_style_operation(expired_account_notification_operation)->>0) = 'expired_account_notification', 'operation "expired_account_notification_operation" error';
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


