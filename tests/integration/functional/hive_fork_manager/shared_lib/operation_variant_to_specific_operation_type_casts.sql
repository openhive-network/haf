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

DROP PROCEDURE IF EXISTS check_operation_to_comment_operation;
CREATE PROCEDURE check_operation_to_comment_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.comment_operation;
BEGIN
  op := '{"type": "comment_operation", "value": {"author": "tattoodjay", "body": "This is a cross post of [@tattoodjay/wednesday-walk-in-buttonwood-park](/hive-194913/@tattoodjay/wednesday-walk-in-buttonwood-park) by @tattoodjay.<br><br>A walk around Buttonwood Park", "json_metadata": "{\"app\":\"peakd/2023.2.2\",\"tags\":[\"cross-post\"],\"image\":[],\"original_author\":\"tattoodjay\", \"original_permlink\":\"wednesday-walk-in-buttonwood-park\"}", "parent_author": "", "parent_permlink": "hive-155530", "permlink": "wednesday-walk-in-buttonwood-park-hive-155530", "title": "Wednesday Walk in Buttonwood Park"}}'::hive.operation::hive.comment_operation;
  ASSERT (select op.parent_author = ''), format('Unexpected value of comment_operation.parent_author: %s', op.parent_author);
  ASSERT (select op.parent_permlink = 'hive-155530'), format('Unexpected value of comment_operation.parent_permlink: %s', op.parent_permlink);
  ASSERT (select op.author = 'tattoodjay'), format('Unexpected value of comment_operation.author: %s', op.author);
  ASSERT (select op.permlink = 'wednesday-walk-in-buttonwood-park-hive-155530'), format('Unexpected value of comment_operation.permlink: %s', op.permlink);
  ASSERT (select op.title = 'Wednesday Walk in Buttonwood Park'), format('Unexpected value of comment_operation.title: %s', op.title);
  ASSERT (select op.body = 'This is a cross post of [@tattoodjay/wednesday-walk-in-buttonwood-park](/hive-194913/@tattoodjay/wednesday-walk-in-buttonwood-park) by @tattoodjay.<br><br>A walk around Buttonwood Park'), format('Unexpected value of comment_operation.body: %s', op.body);
  ASSERT (select op.json_metadata = '{"app": "peakd/2023.2.2", "tags": ["cross-post"], "image": [], "original_author": "tattoodjay", "original_permlink": "wednesday-walk-in-buttonwood-park"}'), format('Unexpected value of comment_operation.json_metadata: %s', op.json_metadata);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_comment_options_operation;
CREATE PROCEDURE check_operation_to_comment_options_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.comment_options_operation;
BEGIN
  op := '{"type": "comment_options_operation", "value": {"allow_curation_rewards": false, "allow_votes": true, "author": "tattoodjay", "extensions": [{"type":"comment_payout_beneficiaries", "value": {"beneficiaries": [{"account": "bob", "weight": 100}, {"account": "eva", "weight": 50}]}},], "max_accepted_payout": {"nai": "@@000000013", "amount": "332", "precision": 3}, "percent_hbd": 10000, "permlink": "wednesday-walk-in-buttonwood-park-hive-155530"}}'::hive.operation::hive.comment_options_operation;
  ASSERT (select op.author = 'tattoodjay'), format('Unexpected value of comment_options_operation.author: %s', op.author);
  ASSERT (select op.permlink = 'wednesday-walk-in-buttonwood-park-hive-155530'), format('Unexpected value of comment_options_operation.permlink: %s', op.permlink);
  ASSERT (select op.max_accepted_payout = '(332,3,@@000000013)'::hive.asset), format('Unexpected value of comment_options_operation.max_accepted_payout: %s', op.max_accepted_payout);
  ASSERT (select op.percent_hbd = 10000), format('Unexpected value of comment_options_operation.percent_hbd: %s', op.percent_hbd);
  ASSERT (select op.allow_votes = True), format('Unexpected value of comment_options_operation.allow_votes: %s', op.allow_votes);
  ASSERT (select op.allow_curation_rewards = 'False'), format('Unexpected value of comment_options_operation.allow_curation_rewards: %s', op.allow_curation_rewards);
  ASSERT (select op.extensions = '("(""{""""(bob,100)"""",""""(eva,50)""""}"")",)'::hive.comment_options_extensions_type), format('Unexpected value of comment_options_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_vote_operation;
CREATE PROCEDURE check_operation_to_vote_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.vote_operation;
BEGIN
  op := '{"type":"vote_operation","value":{"voter":"anthrovegan","author":"carrinm","permlink":"actifit-carrinm-20200311t080841657z","weight":5000}}'::hive.operation::hive.vote_operation;
  ASSERT (select op.voter = 'anthrovegan'), format('Unexpected value of vote_operation.voter: %s', op.voter);
  ASSERT (select op.author = 'carrinm'), format('Unexpected value of vote_operation.author: %s', op.author);
  ASSERT (select op.permlink = 'actifit-carrinm-20200311t080841657z'), format('Unexpected value of vote_operation.permlink: %s', op.permlink);
  ASSERT (select op.weight = 5000), format('Unexpected value of vote_operation.weight: %s', op.weight);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_witness_set_properties_operation;
CREATE PROCEDURE check_operation_to_witness_set_properties_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.witness_set_properties_operation;
BEGIN
  op := '{"type":"witness_set_properties_operation","value":{"owner":"holger80","props":[["account_creation_fee","b80b00000000000003535445454d0000"],["key","0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88"]],"extensions":[]}}'::hive.operation::hive.witness_set_properties_operation;
  ASSERT (select op.owner = 'holger80'), format('Unexpected value of witness_set_properties_operation.owner: %s', op.owner);
  ASSERT (select op.props = '"key"=>"0295a26f54381a6dba8eb5dc7536e57db267685f9386c714ead9be39a905364a88", "account_creation_fee"=>"b80b00000000000003535445454d0000"'), format('Unexpected value of witness_set_properties_operation.props: %s', op.props);
  ASSERT (select op.extensions = '{}'::hive.extensions_type), format('Unexpected value of witness_set_properties_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_account_create_operation;
CREATE PROCEDURE check_operation_to_account_create_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.account_create_operation;
BEGIN
  op := '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"dan","owner":{"weight_threshold":1,"account_auths":[],"key_auths": [["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"posting": {"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"memo_key":"STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH","json_metadata":"{}"}}'::hive.operation::hive.account_create_operation;
  ASSERT (select op.fee = '(0,3,@@000000021)'::hive.asset), format('Unexpected value of account_create_operation.fee: %s', op.fee);
  ASSERT (select op.creator = 'initminer'), format('Unexpected value of account_create_operation.creator: %s', op.creator);
  ASSERT (select op.new_account_name = 'dan'), format('Unexpected value of account_create_operation.new_account_name: %s', op.new_account_name);
  ASSERT (select op.owner = '(1,"","""STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH""=>""1""")'::hive.authority), format('Unexpected value of account_create_operation.owner: %s', op.owner);
  ASSERT (select op.active = '(1,"","""STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH""=>""1""")'::hive.authority), format('Unexpected value of account_create_operation.active: %s', op.active);
  ASSERT (select op.posting = '(1,"","""STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH""=>""1""")'::hive.authority), format('Unexpected value of account_create_operation.posting: %s', op.posting);
  ASSERT (select op.memo_key = 'STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH'), format('Unexpected value of account_create_operation.memo_key: %s', op.memo_key);
  ASSERT (select op.json_metadata = '{}'), format('Unexpected value of account_create_operation.json_metadata: %s', op.json_metadata);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_account_create_with_delegation_operation;
CREATE PROCEDURE check_operation_to_account_create_with_delegation_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.account_create_with_delegation_operation;
BEGIN
  op := '{"type":"account_create_with_delegation_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"delegation":{"amount":"100000000000000","precision":6,"nai":"@@000000037"},"creator":"initminer","new_account_name":"edgar0ah","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8R8maxJxeBMR3JYmap1n3Pypm886oEUjLYdsetzcnPDFpiq3pZ",1]]},"active":{"weight_threshold":1,"account_auths":[], "key_auths":[["STM8R8maxJxeBMR3JYmap1n3Pypm886oEUjLYdsetzcnPDFpiq3pZ",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8ZCsvwKqttXivgPyJ1MYS4q1r3fBZJh3g1SaBxVbfsqNcmnvD3",1]]},"memo_key": "STM8ZCsvwKqttXivgPyJ1MYS4q1r3fBZJh3g1SaBxVbfsqNcmnvD3","json_metadata":"{}","extensions":[]}}'::hive.operation::hive.account_create_with_delegation_operation;
  ASSERT (select op.fee = '(0,3,@@000000021)'::hive.asset), format('Unexpected value of account_create_with_delegation_operation.fee: %s', op.fee);
  ASSERT (select op.delegation = '(100000000000000,6,@@000000037)'::hive.asset), format('Unexpected value of account_create_with_delegation_operation.delegation: %s', op.delegation);
  ASSERT (select op.creator = 'initminer'), format('Unexpected value of account_create_with_delegation_operation.creator: %s', op.creator);
  ASSERT (select op.new_account_name = 'edgar0ah'), format('Unexpected value of account_create_with_delegation_operation.new_account_name: %s', op.new_account_name);
  ASSERT (select op.owner = '(1,"","""STM8R8maxJxeBMR3JYmap1n3Pypm886oEUjLYdsetzcnPDFpiq3pZ""=>""1""")'::hive.authority), format('Unexpected value of account_create_with_delegation_operation.owner: %s', op.owner);
  ASSERT (select op.active = '(1,"","""STM8R8maxJxeBMR3JYmap1n3Pypm886oEUjLYdsetzcnPDFpiq3pZ""=>""1""")'::hive.authority), format('Unexpected value of account_create_with_delegation_operation.active: %s', op.active);
  ASSERT (select op.posting = '(1,"","""STM8ZCsvwKqttXivgPyJ1MYS4q1r3fBZJh3g1SaBxVbfsqNcmnvD3""=>""1""")'::hive.authority), format('Unexpected value of account_create_with_delegation_operation.posting: %s', op.posting);
  ASSERT (select op.memo_key = 'STM8ZCsvwKqttXivgPyJ1MYS4q1r3fBZJh3g1SaBxVbfsqNcmnvD3'), format('Unexpected value of account_create_with_delegation_operation.memo_key: %s', op.memo_key);
  ASSERT (select op.json_metadata = '{}'), format('Unexpected value of account_create_with_delegation_operation.json_metadata: %s', op.json_metadata);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of account_create_with_delegation_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_account_update2_operation;
CREATE PROCEDURE check_operation_to_account_update2_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.account_update2_operation;
BEGIN
  op := '{"type":"account_update2_operation","value":{"account":"ben8ah","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5Wteiod1TC7Wraux73AZvMsjrA5b3E1LTsv1dZa3CB9V4LhXTN",1]]},"memo_key":"STM7NVJSvcpYMSVkt1mzJ7uo8Ema7uwsuSypk9wjNjEK9cDyN6v3S","json_metadata":"{\"success\":true}","posting_json_metadata":"{}","extensions":[]}}'::hive.operation::hive.account_update2_operation;
  ASSERT (select op.account = 'ben8ah'), format('Unexpected value of account_update2_operation.account: %s', op.account);
  ASSERT (select op.owner = '(1,"","""STM5Wteiod1TC7Wraux73AZvMsjrA5b3E1LTsv1dZa3CB9V4LhXTN""=>""1""")'::hive.authority), format('Unexpected value of account_update2_operation.owner: %s', op.owner);
  ASSERT (select op.active IS NULL), format('Unexpected value of account_update2_operation.active: %s', op.active);
  ASSERT (select op.posting IS NULL), format('Unexpected value of account_update2_operation.posting: %s', op.posting);
  ASSERT (select op.memo_key = 'STM7NVJSvcpYMSVkt1mzJ7uo8Ema7uwsuSypk9wjNjEK9cDyN6v3S'), format('Unexpected value of account_update2_operation.memo_key: %s', op.memo_key);
  ASSERT (select op.json_metadata = '{"success": true}'), format('Unexpected value of account_update2_operation.json_metadata: %s', op.json_metadata);
  ASSERT (select op.posting_json_metadata = '{}'), format('Unexpected value of account_update2_operation.posting_json_metadata: %s', op.posting_json_metadata);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of account_update2_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_account_update_operation;
CREATE PROCEDURE check_operation_to_account_update_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.account_update_operation;
BEGIN
  op := '{"type":"account_update_operation","value":{"account":"alice","posting":{"weight_threshold":4,"account_auths":[],"key_auths":[["STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW",1]]},"memo_key":              "STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW","json_metadata":"{}"}}'::hive.operation::hive.account_update_operation;
  ASSERT (select op.account = 'alice'), format('Unexpected value of account_update_operation.account: %s', op.account);
  ASSERT (select op.owner IS NULL), format('Unexpected value of account_update_operation.owner: %s', op.owner);
  ASSERT (select op.active IS NULL), format('Unexpected value of account_update_operation.active: %s', op.active);
  ASSERT (select op.posting = '(4,"","""STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW""=>""1""")'::hive.authority), format('Unexpected value of account_update_operation.posting: %s', op.posting);
  ASSERT (select op.memo_key = 'STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW'), format('Unexpected value of account_update_operation.memo_key: %s', op.memo_key);
  ASSERT (select op.json_metadata = '{}'), format('Unexpected value of account_update_operation.json_metadata: %s', op.json_metadata);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_account_witness_proxy_operation;
CREATE PROCEDURE check_operation_to_account_witness_proxy_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.account_witness_proxy_operation;
BEGIN
  op := '{"type":"account_witness_proxy_operation","value":{"account":"initminer","proxy":"alice"}}'::hive.operation::hive.account_witness_proxy_operation;
  ASSERT (select op.account = 'initminer'), format('Unexpected value of account_witness_proxy_operation.account: %s', op.account);
  ASSERT (select op.proxy = 'alice'), format('Unexpected value of account_witness_proxy_operation.proxy: %s', op.proxy);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_account_witness_vote_operation;
CREATE PROCEDURE check_operation_to_account_witness_vote_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.account_witness_vote_operation;
BEGIN
  op := '{"type":"account_witness_vote_operation","value":{"account":"alice","witness":"initminer","approve":true}}'::hive.operation::hive.account_witness_vote_operation;
  ASSERT (select op.account = 'alice'), format('Unexpected value of account_witness_vote_operation.account: %s', op.account);
  ASSERT (select op.witness = 'initminer'), format('Unexpected value of account_witness_vote_operation.witness: %s', op.witness);
  ASSERT (select op.approve = True), format('Unexpected value of account_witness_vote_operation.approve: %s', op.approve);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_cancel_transfer_from_savings_operation;
CREATE PROCEDURE check_operation_to_cancel_transfer_from_savings_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.cancel_transfer_from_savings_operation;
BEGIN
  op := '{"type":"cancel_transfer_from_savings_operation","value":{"from":"alice","request_id":1}}'::hive.operation::hive.cancel_transfer_from_savings_operation;
  ASSERT (select op."from" = 'alice'), format('Unexpected value of cancel_transfer_from_savings_operation.from: %s', op."from");
  ASSERT (select op.request_id = '1'), format('Unexpected value of cancel_transfer_from_savings_operation.request_id: %s', op.request_id);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_change_recovery_account_operation;
CREATE PROCEDURE check_operation_to_change_recovery_account_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.change_recovery_account_operation;
BEGIN
  op := '{"type":"change_recovery_account_operation","value":{"account_to_recover":"initminer","new_recovery_account":"alice","extensions":[]}}'::hive.operation::hive.change_recovery_account_operation;
  ASSERT (select op.account_to_recover = 'initminer'), format('Unexpected value of change_recovery_account_operation.account_to_recover: %s', op.account_to_recover);
  ASSERT (select op.new_recovery_account = 'alice'), format('Unexpected value of change_recovery_account_operation.new_recovery_account: %s', op.new_recovery_account);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of change_recovery_account_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_claim_account_operation;
CREATE PROCEDURE check_operation_to_claim_account_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.claim_account_operation;
BEGIN
  op := '{"type":"claim_account_operation","value":{"creator":"initminer","fee":{"amount":"0","precision":3,"nai":"@@000000021"},"extensions":[]}}'::hive.operation::hive.claim_account_operation;
  ASSERT (select op.creator = 'initminer'), format('Unexpected value of claim_account_operation.creator: %s', op.creator);
  ASSERT (select op.fee = '(0,3,@@000000021)'::hive.asset), format('Unexpected value of claim_account_operation.fee: %s', op.fee);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of claim_account_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_claim_reward_balance_operation;
CREATE PROCEDURE check_operation_to_claim_reward_balance_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.claim_reward_balance_operation;
BEGIN
  op := '{"type":"claim_reward_balance_operation","value":{"account":"edgar0ah","reward_hive":{"amount":"0","precision":3,"nai":"@@000000021"},"reward_hbd":{"amount":"1","precision":3,"nai":"@@000000013"},"reward_vests":  {"amount":"1","precision":6,"nai":"@@000000037"}}}'::hive.operation::hive.claim_reward_balance_operation;
  ASSERT (select op.account = 'edgar0ah'), format('Unexpected value of claim_reward_balance_operation.account: %s', op.account);
  ASSERT (select op.reward_hive = '(0,3,@@000000021)'::hive.asset), format('Unexpected value of claim_reward_balance_operation.reward_hive: %s', op.reward_hive);
  ASSERT (select op.reward_hbd = '(1,3,@@000000013)'::hive.asset), format('Unexpected value of claim_reward_balance_operation.reward_hbd: %s', op.reward_hbd);
  ASSERT (select op.reward_vests = '(1,6,@@000000037)'::hive.asset), format('Unexpected value of claim_reward_balance_operation.reward_vests: %s', op.reward_vests);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_collateralized_convert_operation;
CREATE PROCEDURE check_operation_to_collateralized_convert_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.collateralized_convert_operation;
BEGIN
  op := '{"type":"collateralized_convert_operation","value":{"owner":"carol3ah","requestid":0,"amount":{"amount":"22102","precision":3,"nai":"@@000000021"}}}'::hive.operation::hive.collateralized_convert_operation;
  ASSERT (select op.owner = 'carol3ah'), format('Unexpected value of collateralized_convert_operation.owner: %s', op.owner);
  ASSERT (select op.requestid = '0'), format('Unexpected value of collateralized_convert_operation.requestid: %s', op.requestid);
  ASSERT (select op.amount = '(22102,3,@@000000021)'::hive.asset), format('Unexpected value of collateralized_convert_operation.amount: %s', op.amount);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_convert_operation;
CREATE PROCEDURE check_operation_to_convert_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.convert_operation;
BEGIN
  op := '{"type": "convert_operation","value": {"amount": {"amount": "127144","nai": "@@000000013","precision": 3},"owner": "gtg","requestid": 1467663446}}'::hive.operation::hive.convert_operation;
  ASSERT (select op.owner = 'gtg'), format('Unexpected value of convert_operation.owner: %s', op.owner);
  ASSERT (select op.requestid = 1467663446), format('Unexpected value of convert_operation.requestid: %s', op.requestid);
  ASSERT (select op.amount = '(127144,3,@@000000013)'::hive.asset), format('Unexpected value of convert_operation.amount: %s', op.amount);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_create_claimed_account_operation;
CREATE PROCEDURE check_operation_to_create_claimed_account_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.create_claimed_account_operation;
BEGIN
  op := '{"type":"create_claimed_account_operation","value":{"creator":"alice8ah","new_account_name":"ben8ah","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7NVJSvcpYMSVkt1mzJ7uo8Ema7uwsuSypk9wjNjEK9cDyN6v3S",1]]},"active": {"weight_threshold":1,"account_auths":[],"key_auths":[["STM7NVJSvcpYMSVkt1mzJ7uo8Ema7uwsuSypk9wjNjEK9cDyN6v3S",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7F7N2n8RYwoBkS3rCtwDkaTdnbkctCm3V3fn2cDvdx988XMNZv", 1]]},"memo_key":"STM7F7N2n8RYwoBkS3rCtwDkaTdnbkctCm3V3fn2cDvdx988XMNZv","json_metadata":"{}","extensions":[]}}'::hive.operation::hive.create_claimed_account_operation;
  ASSERT (select op.creator = 'alice8ah'), format('Unexpected value of create_claimed_account_operation.creator: %s', op.creator);
  ASSERT (select op.new_account_name = 'ben8ah'), format('Unexpected value of create_claimed_account_operation.new_account_name: %s', op.new_account_name);
  ASSERT (select op.owner = '(1,"","""STM7NVJSvcpYMSVkt1mzJ7uo8Ema7uwsuSypk9wjNjEK9cDyN6v3S""=>""1""")'::hive.authority), format('Unexpected value of create_claimed_account_operation.owner: %s', op.owner);
  ASSERT (select op.active = '(1,"","""STM7NVJSvcpYMSVkt1mzJ7uo8Ema7uwsuSypk9wjNjEK9cDyN6v3S""=>""1""")'::hive.authority), format('Unexpected value of create_claimed_account_operation.active: %s', op.active);
  ASSERT (select op.posting = '(1,"","""STM7F7N2n8RYwoBkS3rCtwDkaTdnbkctCm3V3fn2cDvdx988XMNZv""=>""1""")'::hive.authority), format('Unexpected value of create_claimed_account_operation.posting: %s', op.posting);
  ASSERT (select op.memo_key = 'STM7F7N2n8RYwoBkS3rCtwDkaTdnbkctCm3V3fn2cDvdx988XMNZv'), format('Unexpected value of create_claimed_account_operation.memo_key: %s', op.memo_key);
  ASSERT (select op.json_metadata = '{}'), format('Unexpected value of create_claimed_account_operation.json_metadata: %s', op.json_metadata);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of create_claimed_account_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_custom_json_operation;
CREATE PROCEDURE check_operation_to_custom_json_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.custom_json_operation;
BEGIN
  op := '{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["alice"],"id":"follow","json":"{\"type\":\"follow_operation\",\"value\":{\"follower\":\"alice\",\"following\":\"@bob\",\"what\":[\"blog\"]}}"}}'::hive.operation::hive.custom_json_operation;
  ASSERT (select op.required_auths = '{}'), format('Unexpected value of custom_json_operation.required_auths: %s', op.required_auths);
  ASSERT (select op.required_posting_auths = '{alice}'), format('Unexpected value of custom_json_operation.required_posting_auths: %s', op.required_posting_auths);
  ASSERT (select op.id = 'follow'), format('Unexpected value of custom_json_operation.id: %s', op.id);
  ASSERT (select op.json = '{"type":"follow_operation","value":{"follower":"alice","following":"@bob","what":["blog"]}}'), format('Unexpected value of custom_json_operation.json: %s', op.json);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_custom_operation;
CREATE PROCEDURE check_operation_to_custom_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.custom_operation;
BEGIN
  op := '{"type": "custom_operation","value": {"data":"0a627974656d617374657207737465656d697402a3d13897d82114466ad87a74b73a53292d8331d1bd1d3082da6bfbcff19ed097029db013797711c88cccca3692407f9ff9b9ce7221aaa2d797f1692be2215d0a5f6d2a8cab6832050078bc5729201e3ea24ea9f7873e6dbdc65a6bd9899053b9acda876dc69f11a13df9ca8b26b6","id": 777,"required_auths": ["bytemaster"]}}'::hive.operation::hive.custom_operation;
  ASSERT (select op.required_auths = '{bytemaster}'), format('Unexpected value of custom_operation.required_auths: %s', op.required_auths);
  ASSERT (select op.id = 777), format('Unexpected value of custom_operation.id: %s', op.id);
  ASSERT (select op.data = '\x0a627974656d617374657207737465656d697402a3d13897d82114466ad87a74b73a53292d8331d1bd1d3082da6bfbcff19ed097029db013797711c88cccca3692407f9ff9b9ce7221aaa2d797f1692be2215d0a5f6d2a8cab6832050078bc5729201e3ea24ea9f7873e6dbdc65a6bd9899053b9acda876dc69f11a13df9ca8b26b6'), format('Unexpected value of custom_operation.data: %s', op.data);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_decline_voting_rights_operation;
CREATE PROCEDURE check_operation_to_decline_voting_rights_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.decline_voting_rights_operation;
BEGIN
  op := '{"type":"decline_voting_rights_operation","value":{"account":"initminer","decline":true}}'::hive.operation::hive.decline_voting_rights_operation;
  ASSERT (select op.account = 'initminer'), format('Unexpected value of decline_voting_rights_operation.account: %s', op.account);
  ASSERT (select op.decline = True), format('Unexpected value of decline_voting_rights_operation.decline: %s', op.decline);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_delegate_vesting_shares_operation;
CREATE PROCEDURE check_operation_to_delegate_vesting_shares_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.delegate_vesting_shares_operation;
BEGIN
  op := '{"type":"delegate_vesting_shares_operation","value":{"delegator":"alice","delegatee":"bob","vesting_shares":{"amount":"1000000","precision":6,"nai":"@@000000037"}}}'::hive.operation::hive.delegate_vesting_shares_operation;
  ASSERT (select op.delegator = 'alice'), format('Unexpected value of delegate_vesting_shares_operation.delegator: %s', op.delegator);
  ASSERT (select op.delegatee = 'bob'), format('Unexpected value of delegate_vesting_shares_operation.delegatee: %s', op.delegatee);
  ASSERT (select op.vesting_shares = '(1000000,6,@@000000037)'::hive.asset), format('Unexpected value of delegate_vesting_shares_operation.vesting_shares: %s', op.vesting_shares);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_delete_comment_operation;
CREATE PROCEDURE check_operation_to_delete_comment_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.delete_comment_operation;
BEGIN
  op := '{"type": "delete_comment_operation","value": {"author": "camilla","permlink": "re-shenanigator-re-kalipo-re-camilla-girl-with-a-pink-bow-20160912t221343480z"}}'::hive.operation::hive.delete_comment_operation;
  ASSERT (select op.author = 'camilla'), format('Unexpected value of delete_comment_operation.author: %s', op.author);
  ASSERT (select op.permlink = 're-shenanigator-re-kalipo-re-camilla-girl-with-a-pink-bow-20160912t221343480z'), format('Unexpected value of delete_comment_operation.permlink: %s', op.permlink);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_escrow_approve_operation;
CREATE PROCEDURE check_operation_to_escrow_approve_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.escrow_approve_operation;
BEGIN
  op := '{"type":"escrow_approve_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"bob","escrow_id":2,"approve":true}}'::hive.operation::hive.escrow_approve_operation;
  ASSERT (select op."from" = 'initminer'), format('Unexpected value of escrow_approve_operation.from: %s', op.from);
  ASSERT (select op."to" = 'alice'), format('Unexpected value of escrow_approve_operation.to: %s', op.to);
  ASSERT (select op.agent = 'bob'), format('Unexpected value of escrow_approve_operation.agent: %s', op.agent);
  ASSERT (select op.who = 'bob'), format('Unexpected value of escrow_approve_operation.who: %s', op.who);
  ASSERT (select op.escrow_id = 2), format('Unexpected value of escrow_approve_operation.escrow_id: %s', op.escrow_id);
  ASSERT (select op.approve = True), format('Unexpected value of escrow_approve_operation.approve: %s', op.approve);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_escrow_dispute_operation;
CREATE PROCEDURE check_operation_to_escrow_dispute_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.escrow_dispute_operation;
BEGIN
  op := '{"type":"escrow_dispute_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"initminer","escrow_id":3}}'::hive.operation::hive.escrow_dispute_operation;
  ASSERT (select op."from" = 'initminer'), format('Unexpected value of escrow_dispute_operation.from: %s', op."from");
  ASSERT (select op."to" = 'alice'), format('Unexpected value of escrow_dispute_operation.to: %s', op."to");
  ASSERT (select op.agent = 'bob'), format('Unexpected value of escrow_dispute_operation.agent: %s', op.agent);
  ASSERT (select op.who = 'initminer'), format('Unexpected value of escrow_dispute_operation.who: %s', op.who);
  ASSERT (select op.escrow_id = 3), format('Unexpected value of escrow_dispute_operation.escrow_id: %s', op.escrow_id);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_escrow_release_operation;
CREATE PROCEDURE check_operation_to_escrow_release_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.escrow_release_operation;
BEGIN
  op := '{"type":"escrow_release_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"bob","receiver":"alice","escrow_id":1,"hbd_amount":{"amount":"10000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"10000", "precision":3,"nai":"@@000000021"}}}'::hive.operation::hive.escrow_release_operation;
  ASSERT (select op."from" = 'initminer'), format('Unexpected value of escrow_release_operation.from: %s', op."from");
  ASSERT (select op."to" = 'alice'), format('Unexpected value of escrow_release_operation.to: %s', op."to");
  ASSERT (select op.agent = 'bob'), format('Unexpected value of escrow_release_operation.agent: %s', op.agent);
  ASSERT (select op.who = 'bob'), format('Unexpected value of escrow_release_operation.who: %s', op.who);
  ASSERT (select op.receiver = 'alice'), format('Unexpected value of escrow_release_operation.receiver: %s', op.receiver);
  ASSERT (select op.escrow_id = 1), format('Unexpected value of escrow_release_operation.escrow_id: %s', op.escrow_id);
  ASSERT (select op.hbd_amount = '(10000,3,@@000000013)'::hive.asset), format('Unexpected value of escrow_release_operation.hbd_amount: %s', op.hbd_amount);
  ASSERT (select op.hive_amount = '(10000,3,@@000000021)'::hive.asset), format('Unexpected value of escrow_release_operation.hive_amount: %s', op.hive_amount);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_escrow_transfer_operation;
CREATE PROCEDURE check_operation_to_escrow_transfer_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.escrow_transfer_operation;
BEGIN
  op := '{"type":"escrow_transfer_operation","value":{"from":"initminer","to":"alice","hbd_amount":{"amount":"10000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"10000","precision":3,"nai":"@@000000021"},"escrow_id":10,"agent": "bob","fee":{"amount":"10000","precision":3,"nai":"@@000000013"},"json_meta":"{}","ratification_deadline":"2030-01-01T00:00:00","escrow_expiration":"2030-06-01T00:00:00"}}'::hive.operation::hive.escrow_transfer_operation;
  ASSERT (select op."from" = 'initminer'), format('Unexpected value of escrow_transfer_operation.from: %s', op."from");
  ASSERT (select op."to" = 'alice'), format('Unexpected value of escrow_transfer_operation.to: %s', op."to");
  ASSERT (select op.agent = 'bob'), format('Unexpected value of escrow_transfer_operation.agent: %s', op.agent);
  ASSERT (select op.escrow_id = 10), format('Unexpected value of escrow_transfer_operation.escrow_id: %s', op.escrow_id);
  ASSERT (select op.hbd_amount = '(10000,3,@@000000013)'::hive.asset), format('Unexpected value of escrow_transfer_operation.hbd_amount: %s', op.hbd_amount);
  ASSERT (select op.hive_amount = '(10000,3,@@000000021)'::hive.asset), format('Unexpected value of escrow_transfer_operation.hive_amount: %s', op.hive_amount);
  ASSERT (select op.fee = '(10000,3,@@000000013)'::hive.asset), format('Unexpected value of escrow_transfer_operation.fee: %s', op.fee);
  ASSERT (select op.ratification_deadline = '2030-01-01 00:00:00'), format('Unexpected value of escrow_transfer_operation.ratification_deadline: %s', op.ratification_deadline);
  ASSERT (select op.escrow_expiration = '2030-06-01 00:00:00'), format('Unexpected value of escrow_transfer_operation.escrow_expiration: %s', op.escrow_expiration);
  ASSERT (select op.json_meta = '{}'), format('Unexpected value of escrow_transfer_operation.json_meta: %s', op.json_meta);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_feed_publish_operation;
CREATE PROCEDURE check_operation_to_feed_publish_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.feed_publish_operation;
BEGIN
  op := '{"type":"feed_publish_operation","value":{"publisher":"initminer","exchange_rate":{"base":{"amount":"1","precision":3,"nai":"@@000000013"},"quote":{"amount":"2","precision":3,"nai":"@@000000021"}}}}'::hive.operation::hive.feed_publish_operation;
  ASSERT (select op.publisher = 'initminer'), format('Unexpected value of feed_publish_operation.publisher: %s', op.publisher);
  ASSERT (select op.exchange_rate = '("(1,3,@@000000013)","(2,3,@@000000021)")'::hive.price), format('Unexpected value of feed_publish_operation.exchange_rate: %s', op.exchange_rate);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_limit_order_cancel_operation;
CREATE PROCEDURE check_operation_to_limit_order_cancel_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.limit_order_cancel_operation;
BEGIN
  op := '{"type":"limit_order_cancel_operation","value":{"owner":"alice","orderid":1}}'::hive.operation::hive.limit_order_cancel_operation;
  ASSERT (select op.owner = 'alice'), format('Unexpected value of limit_order_cancel_operation.owner: %s', op.owner);
  ASSERT (select op.orderid = 1), format('Unexpected value of limit_order_cancel_operation.orderid: %s', op.orderid);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_limit_order_create2_operation;
CREATE PROCEDURE check_operation_to_limit_order_create2_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.limit_order_create2_operation;
BEGIN
  op := '{"type":"limit_order_create2_operation","value":{"owner":"carol3ah","orderid":2,"amount_to_sell":{"amount":"22075","precision":3,"nai":"@@000000021"},"exchange_rate":{"base":{"amount":"10","precision":3,"nai":"@@000000021"},"quote": {"amount":"10","precision":3,"nai":"@@000000013"}},"fill_or_kill":false,"expiration":"2016-01-29T00:00:12"}}'::hive.operation::hive.limit_order_create2_operation;
  ASSERT (select op.owner = 'carol3ah'), format('Unexpected value of limit_order_create2_operation.owner: %s', op.owner);
  ASSERT (select op.orderid = 2), format('Unexpected value of limit_order_create2_operation.orderid: %s', op.orderid);
  ASSERT (select op.amount_to_sell = '(22075,3,@@000000021)'::hive.asset), format('Unexpected value of limit_order_create2_operation.amount_to_sell: %s', op.amount_to_sell);
  ASSERT (select op.fill_or_kill = False), format('Unexpected value of limit_order_create2_operation.fill_or_kill: %s', op.fill_or_kill);
  ASSERT (select op.exchange_rate = '("(10,3,@@000000021)","(10,3,@@000000013)")'::hive.price), format('Unexpected value of limit_order_create2_operation.exchange_rate: %s', op.exchange_rate);
  ASSERT (select op.expiration = '2016-01-29 00:00:12'), format('Unexpected value of limit_order_create2_operation.expiration: %s', op.expiration);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_limit_order_create_operation;
CREATE PROCEDURE check_operation_to_limit_order_create_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.limit_order_create_operation;
BEGIN
  op := '{"type":"limit_order_create_operation","value":{"owner":"alice","orderid":1000,"amount_to_sell":{"amount":"1000","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"500","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2023-01-02T11:43:07"}}'::hive.operation::hive.limit_order_create_operation;
  ASSERT (select op.owner = 'alice'), format('Unexpected value of limit_order_create_operation.owner: %s', op.owner);
  ASSERT (select op.orderid = 1000), format('Unexpected value of limit_order_create_operation.orderid: %s', op.orderid);
  ASSERT (select op.amount_to_sell = '(1000,3,@@000000021)'::hive.asset), format('Unexpected value of limit_order_create_operation.amount_to_sell: %s', op.amount_to_sell);
  ASSERT (select op.min_to_receive = '(500,3,@@000000013)'::hive.asset), format('Unexpected value of limit_order_create_operation.min_to_receive: %s', op.min_to_receive);
  ASSERT (select op.fill_or_kill = False), format('Unexpected value of limit_order_create_operation.fill_or_kill: %s', op.fill_or_kill);
  ASSERT (select op.expiration = '2023-01-02 11:43:07'), format('Unexpected value of limit_order_create_operation.expiration: %s', op.expiration);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_pow2_operation;
CREATE PROCEDURE check_operation_to_pow2_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.pow2_operation;
BEGIN
  op := '{"type": "pow2_operation","value": {"props": {"account_creation_fee": {"amount": "1","nai": "@@000000021","precision": 3},"hbd_interest_rate": 1000,"maximum_block_size": 131072},"work": {"type": "pow2","value": {"input": {"nonce": "2363830237862599931","prev_block": "003ead0c90b0cd80e9145805d303957015c50ef1","worker_account": "thedao"},"pow_summary": 3878270667}}}}'::hive.operation::hive.pow2_operation;
  ASSERT (select op.work = '("(""(thedao,""""""\\\\\\\\x30303365616430633930623063643830653931343538303564333033393537303135633530656631"""""",2363830237862599931)"",3878270667)",)'::hive.pow2_work), format('Unexpected value of pow2_operation.work: %s', op.work);
  ASSERT (select op.new_owner_key IS NULL), format('Unexpected value of pow2_operation.new_owner_key: %s', op.new_owner_key);
  ASSERT (select op.props = '("(1,3,@@000000021)",131072,1000)'::hive.legacy_chain_properties), format('Unexpected value of pow2_operation.props: %s', op.props);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_pow_operation;
CREATE PROCEDURE check_operation_to_pow_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.pow_operation;
BEGIN
  op := '{"type": "pow_operation","value": {"block_id": "002104af55d5c492c8c134b5a55c89eac8210a86","nonce": "6317456790497374569","props": {"account_creation_fee": {"amount": "1","nai": "@@000000021","precision": 3}, "hbd_interest_rate": 1000,"maximum_block_size": 131072},"work": {"input": "d28a6c6f0fd04548ef12833d3e95acf7690cfb2bc6f6c8cd3b277d2f234bd908","signature": "20bd759200fb6996e141f1968beb3ef7d37a1692f15dc3a6c930388b27ec8691c07e36d3a0f441de10d12b2b1c98ed0816d3c2dfe1c8be1eacfd27fe5f4dd7f07a","work": "0000000c822c37f6a18985b1ef0eac34ae51f9e87d9ce3a8a217c90c7d74d82e", "worker": "STM5DHtHTDTyr3A4uutu6EsnHPfxAfRo9gQoJRT7jAHw4eU4UWRCK"},"worker_account": "badger3143"}}'::hive.operation::hive.pow_operation;
  ASSERT (select op.worker_account = 'badger3143'), format('Unexpected value of pow_operation.worker_account: %s', op.worker_account);
  ASSERT (select op.block_id = '\x30303231303461663535643563343932633863313334623561353563383965616338323130613836'), format('Unexpected value of pow_operation.block_id: %s', op.block_id);
  ASSERT (select op.nonce = '6317456790497374569'), format('Unexpected value of pow_operation.nonce: %s', op.nonce);
  ASSERT (select op.work = '(STM5DHtHTDTyr3A4uutu6EsnHPfxAfRo9gQoJRT7jAHw4eU4UWRCK,"\\x64323861366336663066643034353438656631323833336433653935616366373639306366623262633666366338636433623237376432663233346264393038","\\x20bd759200fb6996e141f1968beb3ef7d37a1692f15dc3a6c930388b27ec8691c07e36d3a0f441de10d12b2b1c98ed0816d3c2dfe1c8be1eacfd27fe5f4dd7f07a","\\x30303030303030633832326333376636613138393835623165663065616333346165353166396538376439636533613861323137633930633764373464383265")'::hive.pow), format('Unexpected value of pow_operation.work: %s', op.work);
  ASSERT (select op.props = '("(1,3,@@000000021)",131072,1000)'::hive.legacy_chain_properties), format('Unexpected value of pow_operation.props: %s', op.props);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_recover_account_operation;
CREATE PROCEDURE check_operation_to_recover_account_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.recover_account_operation;
BEGIN
  op := '{"type": "recover_account_operation","value": {"account_to_recover": "gtg","extensions": [],"new_owner_authority": {"account_auths": [],"key_auths": [["STM5RLQ1Jh8Kf56go3xpzoodg4vRsgCeWhANXoEXrYH7bLEwSVyjh",1]],"weight_threshold": 1},"recent_owner_authority": {"account_auths": [],"key_auths": [["STM5F9tCbND6zWPwksy1rEN24WjPiQWSU2vwGgegQVjAcYDe1zTWi",1]],"weight_threshold": 1}}}'::hive.operation::hive.recover_account_operation;
  ASSERT (select op.account_to_recover = 'gtg'), format('Unexpected value of recover_account_operation.account_to_recover: %s', op.account_to_recover);
  ASSERT (select op.new_owner_authority = '(1,"","""STM5RLQ1Jh8Kf56go3xpzoodg4vRsgCeWhANXoEXrYH7bLEwSVyjh""=>""1""")'::hive.authority), format('Unexpected value of recover_account_operation.new_owner_authority: %s', op.new_owner_authority);
  ASSERT (select op.recent_owner_authority = '(1,"","""STM5F9tCbND6zWPwksy1rEN24WjPiQWSU2vwGgegQVjAcYDe1zTWi""=>""1""")'::hive.authority), format('Unexpected value of recover_account_operation.recent_owner_authority: %s', op.recent_owner_authority);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of recover_account_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_recurrent_transfer_operation;
CREATE PROCEDURE check_operation_to_recurrent_transfer_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.recurrent_transfer_operation;
BEGIN
  op := '{"type":"recurrent_transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"memo","recurrence":720,"executions":12,"extensions":[]}}'::hive.operation::hive.recurrent_transfer_operation;
  ASSERT (select op."from" = 'alice'), format('Unexpected value of recurrent_transfer_operation.from: %s', op."from");
  ASSERT (select op."to" = 'bob'), format('Unexpected value of recurrent_transfer_operation.to: %s', op."to");
  ASSERT (select op.amount = '(5000,3,@@000000021)'::hive.asset), format('Unexpected value of recurrent_transfer_operation.amount: %s', op.amount);
  ASSERT (select op.memo = 'memo'), format('Unexpected value of recurrent_transfer_operation.memo: %s', op.memo);
  ASSERT (select op.recurrence = 720), format('Unexpected value of recurrent_transfer_operation.recurrence: %s', op.recurrence);
  ASSERT (select op.executions = 12), format('Unexpected value of recurrent_transfer_operation.executions: %s', op.executions);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of recurrent_transfer_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_request_account_recovery_operation;
CREATE PROCEDURE check_operation_to_request_account_recovery_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.request_account_recovery_operation;
BEGIN
  op := '{"type": "request_account_recovery_operation","value": {"account_to_recover": "tulpa","extensions": [],"new_owner_authority": {"account_auths": [],"key_auths": [["STM6wxeXR9kg8uu7vX5LS4HBgKw8sdqHBpzAaacqPwPxYfRx9h5bS",2]],"weight_threshold": 1},"recovery_account": "nalesnik"}}'::hive.operation::hive.request_account_recovery_operation;
  ASSERT (select op.recovery_account = 'nalesnik'), format('Unexpected value of request_account_recovery_operation.recovery_account: %s', op.recovery_account);
  ASSERT (select op.account_to_recover = 'tulpa'), format('Unexpected value of request_account_recovery_operation.account_to_recover: %s', op.account_to_recover);
  ASSERT (select op.new_owner_authority = '(1,"","""STM6wxeXR9kg8uu7vX5LS4HBgKw8sdqHBpzAaacqPwPxYfRx9h5bS""=>""2""")'::hive.authority), format('Unexpected value of request_account_recovery_operation.new_owner_authority: %s', op.new_owner_authority);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of request_account_recovery_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_set_withdraw_vesting_route_operation;
CREATE PROCEDURE check_operation_to_set_withdraw_vesting_route_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.set_withdraw_vesting_route_operation;
BEGIN
  op := '{"type":"set_withdraw_vesting_route_operation","value":{"from_account":"alice","to_account":"bob","percent":30,"auto_vest":true}}'::hive.operation::hive.set_withdraw_vesting_route_operation;
  ASSERT (select op.from_account = 'alice'), format('Unexpected value of set_withdraw_vesting_route_operation.from_account: %s', op.from_account);
  ASSERT (select op.to_account = 'bob'), format('Unexpected value of set_withdraw_vesting_route_operation.to_account: %s', op.to_account);
  ASSERT (select op.percent = 30), format('Unexpected value of set_withdraw_vesting_route_operation.percent: %s', op.percent);
  ASSERT (select op.auto_vest = True), format('Unexpected value of set_withdraw_vesting_route_operation.auto_vest: %s', op.auto_vest);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_transfer_from_savings_operation;
CREATE PROCEDURE check_operation_to_transfer_from_savings_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.transfer_from_savings_operation;
BEGIN
  op := '{"type":"transfer_from_savings_operation","value":{"from":"alice","request_id":1000,"to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"memo"}}'::hive.operation::hive.transfer_from_savings_operation;
  ASSERT (select op."from" = 'alice'), format('Unexpected value of transfer_from_savings_operation.from: %s', op."from");
  ASSERT (select op.request_id = 1000), format('Unexpected value of transfer_from_savings_operation.request_id: %s', op.request_id);
  ASSERT (select op."to" = 'bob'), format('Unexpected value of transfer_from_savings_operation.to: %s', op."to");
  ASSERT (select op.amount = '(1000,3,@@000000021)'::hive.asset), format('Unexpected value of transfer_from_savings_operation.amount: %s', op.amount);
  ASSERT (select op.memo = 'memo'), format('Unexpected value of transfer_from_savings_operation.memo: %s', op.memo);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_transfer_operation;
CREATE PROCEDURE check_operation_to_transfer_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.transfer_operation;
BEGIN
  op := '{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"10000","precision":3,"nai":"@@000000021"},"memo":"memo"}}'::hive.operation::hive.transfer_operation;
  ASSERT (select op."from" = 'initminer'), format('Unexpected value of transfer_operation.from: %s', op."from");
  ASSERT (select op."to" = 'alice'), format('Unexpected value of transfer_operation.to: %s', op."to");
  ASSERT (select op.amount = '(10000,3,@@000000021)'::hive.asset), format('Unexpected value of transfer_operation.amount: %s', op.amount);
  ASSERT (select op.memo = 'memo'), format('Unexpected value of transfer_operation.memo: %s', op.memo);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_transfer_to_savings_operation;
CREATE PROCEDURE check_operation_to_transfer_to_savings_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.transfer_to_savings_operation;
BEGIN
  op := '{"type":"transfer_to_savings_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"100000","precision":3,"nai":"@@000000021"},"memo":"memo"}}'::hive.operation::hive.transfer_to_savings_operation;
  ASSERT (select op."from" = 'initminer'), format('Unexpected value of transfer_to_savings_operation.from: %s', op."from");
  ASSERT (select op."to" = 'alice'), format('Unexpected value of transfer_to_savings_operation.to: %s', op."to");
  ASSERT (select op.amount = '(100000,3,@@000000021)'::hive.asset), format('Unexpected value of transfer_to_savings_operation.amount: %s', op.amount);
  ASSERT (select op.memo = 'memo'), format('Unexpected value of transfer_to_savings_operation.memo: %s', op.memo);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_transfer_to_vesting_operation;
CREATE PROCEDURE check_operation_to_transfer_to_vesting_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.transfer_to_vesting_operation;
BEGIN
  op := '{"type":"transfer_to_vesting_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"100000","precision":3,"nai":"@@000000021"}}}'::hive.operation::hive.transfer_to_vesting_operation;
  ASSERT (select op."from" = 'initminer'), format('Unexpected value of transfer_to_vesting_operation.from: %s', op."from");
  ASSERT (select op."to" = 'alice'), format('Unexpected value of transfer_to_vesting_operation.to: %s', op."to");
  ASSERT (select op.amount = '(100000,3,@@000000021)'::hive.asset), format('Unexpected value of transfer_to_vesting_operation.amount: %s', op.amount);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_withdraw_vesting_operation;
CREATE PROCEDURE check_operation_to_withdraw_vesting_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.withdraw_vesting_operation;
BEGIN
  op := '{"type":"withdraw_vesting_operation","value":{"account":"alice","vesting_shares":{"amount":"10000000","precision":6,"nai":"@@000000037"}}}'::hive.operation::hive.withdraw_vesting_operation;
  ASSERT (select op."to" = 'alice'), format('Unexpected value of withdraw_vesting_operation.to: %s', op."to");
  ASSERT (select op.vesting_shares = '(10000000,6,@@000000037)'::hive.asset), format('Unexpected value of withdraw_vesting_operation.vesting_shares: %s', op.vesting_shares);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_witness_update_operation;
CREATE PROCEDURE check_operation_to_witness_update_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.witness_update_operation;
BEGIN
  op := '{"type":"witness_update_operation","value":{"owner":"alice","url":"http://url.html","block_signing_key":"STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW","props":{"account_creation_fee":{"amount":"10000", "precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}'::hive.operation::hive.witness_update_operation;
  ASSERT (select op.owner = 'alice'), format('Unexpected value of witness_update_operation.owner: %s', op.owner);
  ASSERT (select op.url = 'http://url.html'), format('Unexpected value of witness_update_operation.url: %s', op.url);
  ASSERT (select op.block_signing_key = 'STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW'), format('Unexpected value of witness_update_operation.block_signing_key: %s', op.block_signing_key);
  ASSERT (select op.props = '("(10000,3,@@000000021)",131072,1000)'::hive.legacy_chain_properties), format('Unexpected value of witness_update_operation.props: %s', op.props);
  ASSERT (select op.fee = '(0,3,@@000000021)'::hive.asset), format('Unexpected value of witness_update_operation.fee: %s', op.fee);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_create_proposal_operation;
CREATE PROCEDURE check_operation_to_create_proposal_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.create_proposal_operation;
BEGIN
  op := '{"type":"create_proposal_operation","value":{"creator":"alice","receiver":"bob","start_date":"2031-01-01T00:00:01","end_date":"2031-06-01T23:59:59","daily_pay":{"amount":"1000000","precision":3,"nai":"@@000000013"},"subject":"subject-1","permlink":"permlink","extensions":[]}}'::hive.operation::hive.create_proposal_operation;
  ASSERT (select op.creator = 'alice'), format('Unexpected value of create_proposal_operation.creator: %s', op.creator);
  ASSERT (select op.receiver = 'bob'), format('Unexpected value of create_proposal_operation.receiver: %s', op.receiver);
  ASSERT (select op.start_date = '2031-01-01 00:00:01'), format('Unexpected value of create_proposal_operation.start_date: %s', op.start_date);
  ASSERT (select op.end_date = '2031-06-01 23:59:59'), format('Unexpected value of create_proposal_operation.end_date: %s', op.end_date);
  ASSERT (select op.daily_pay = '(1000000,3,@@000000013)'::hive.asset), format('Unexpected value of create_proposal_operation.daily_pay: %s', op.daily_pay);
  ASSERT (select op.subject = 'subject-1'), format('Unexpected value of create_proposal_operation.subject: %s', op.subject);
  ASSERT (select op.permlink = 'permlink'), format('Unexpected value of create_proposal_operation.permlink: %s', op.permlink);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of create_proposal_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_proposal_pay_operation;
CREATE PROCEDURE check_operation_to_proposal_pay_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.proposal_pay_operation;
BEGIN
  op := '{"type":"proposal_pay_operation","value":{"proposal_id":0,"receiver":"steem.dao","payer":"steem.dao","payment":{"amount":"157","precision":3,"nai":"@@000000013"},"trx_id":"0000000000000000000000000000000000000000","op_in_trx":0}}'::hive.operation::hive.proposal_pay_operation;
  ASSERT (select op.proposal_id = 0), format('Unexpected value of proposal_pay_operation.proposal_id: %s', op.proposal_id);
  ASSERT (select op.receiver = 'steem.dao'), format('Unexpected value of proposal_pay_operation.receiver: %s', op.receiver);
  ASSERT (select op.payer = 'steem.dao'), format('Unexpected value of proposal_pay_operation.payer: %s', op.payer);
  ASSERT (select op.payment = '(157,3,@@000000013)'::hive.asset), format('Unexpected value of proposal_pay_operation.payment: %s', op.payment);
  ASSERT (select op.trx_id = '\x30303030303030303030303030303030303030303030303030303030303030303030303030303030'), format('Unexpected value of proposal_pay_operation.trx_id: %s', op.trx_id);
  ASSERT (select op.op_in_trx = 0), format('Unexpected value of proposal_pay_operation.op_in_trx: %s', op.op_in_trx);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_remove_proposal_operation;
CREATE PROCEDURE check_operation_to_remove_proposal_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.remove_proposal_operation;
BEGIN
  op := '{"type":"remove_proposal_operation","value":{"proposal_owner":"initminer","proposal_ids":[6],"extensions":[]}}'::hive.operation::hive.remove_proposal_operation;
  ASSERT (select op.proposal_owner = 'initminer'), format('Unexpected value of remove_proposal_operation.proposal_owner: %s', op.proposal_owner);
  ASSERT (select op.proposal_ids = array['6'::Decimal]), format('Unexpected value of remove_proposal_operation.proposal_ids: %s', op.proposal_ids);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of remove_proposal_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_update_proposal_operation;
CREATE PROCEDURE check_operation_to_update_proposal_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.update_proposal_operation;
BEGIN
  op := '{"type":"update_proposal_operation","value":{"proposal_id":0,"creator":"alice","daily_pay":{"amount":"10000","precision":3,"nai":"@@000000013"},"subject":"subject-1","permlink":"permlink","extensions":[{"type": "update_proposal_end_date","value":{"end_date":"2031-05-01T00:00:00"}}]}}'::hive.operation::hive.update_proposal_operation;
  ASSERT (select op.proposal_id = 0), format('Unexpected value of update_proposal_operation.proposal_id: %s', op.proposal_id);
  ASSERT (select op.creator = 'alice'), format('Unexpected value of update_proposal_operation.creator: %s', op.creator);
  ASSERT (select op.daily_pay = '(10000,3,@@000000013)'::hive.asset), format('Unexpected value of update_proposal_operation.daily_pay: %s', op.daily_pay);
  ASSERT (select op.subject = 'subject-1'), format('Unexpected value of update_proposal_operation.subject: %s', op.subject);
  ASSERT (select op.permlink = 'permlink'), format('Unexpected value of update_proposal_operation.permlink: %s', op.permlink);
  ASSERT (select op.extensions = '("(""2031-05-01 00:00:00"")")'::hive.update_proposal_extensions_type), format('Unexpected value of update_proposal_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_update_proposal_votes_operation;
CREATE PROCEDURE check_operation_to_update_proposal_votes_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.update_proposal_votes_operation;
BEGIN
  op := '{"type":"update_proposal_votes_operation","value":{"voter":"alice","proposal_ids":[0],"approve":true,"extensions":[]}}'::hive.operation::hive.update_proposal_votes_operation;
  ASSERT (select op.voter = 'alice'), format('Unexpected value of update_proposal_votes_operation.voter: %s', op.voter);
  ASSERT (select op.proposal_ids = array[0::Decimal]), format('Unexpected value of update_proposal_votes_operation.proposal_ids: %s', op.proposal_ids);
  ASSERT (select op.approve = True), format('Unexpected value of update_proposal_votes_operation.approve: %s', op.approve);
  ASSERT (select op.extensions = '{}'), format('Unexpected value of update_proposal_votes_operation.extensions: %s', op.extensions);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_account_created_operation;
CREATE PROCEDURE check_operation_to_account_created_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.account_created_operation;
BEGIN
  op := '{"type": "account_created_operation","value": {"creator": "steem","initial_delegation": {"amount": "0","nai": "@@000000037","precision": 6},"initial_vesting_shares": {"amount": "11541527333","nai": "@@000000037","precision": 6},"new_account_name": "jevt"}}'::hive.operation::hive.account_created_operation;
  ASSERT (select op.new_account_name = 'jevt'), format('Unexpected value of account_created_operation.new_account_name: %s', op.new_account_name);
  ASSERT (select op.creator = 'steem'), format('Unexpected value of account_created_operation.creator: %s', op.creator);
  ASSERT (select op.initial_vesting_shares = '(11541527333,6,@@000000037)'::hive.asset), format('Unexpected value of account_created_operation.initial_vesting_shares: %s', op.initial_vesting_shares);
  ASSERT (select op.initial_delegation = '(0,6,@@000000037)'::hive.asset), format('Unexpected value of account_created_operation.initial_delegation: %s', op.initial_delegation);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_author_reward_operation;
CREATE PROCEDURE check_operation_to_author_reward_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.author_reward_operation;
BEGIN
  op := '{"type": "author_reward_operation","value": {"author": "camilla","curators_vesting_payout": {"amount": "395495911","nai": "@@000000037","precision": 6},"hbd_payout": {"amount": "138","nai": "@@000000013", "precision": 3},"hive_payout": {"amount": "0","nai": "@@000000021","precision": 3},"payout_must_be_claimed": false,"permlink": "re-spetey-re-camilla-re-spetey-re-clains-free-will-and-conscious-freedom-20160814t111905211z","vesting_payout": {"amount": "611497524","nai": "@@000000037","precision": 6}}}'::hive.operation::hive.author_reward_operation;
  ASSERT (select op.author = 'camilla'), format('Unexpected value of author_reward_operation.author: %s', op.author);
  ASSERT (select op.permlink = 're-spetey-re-camilla-re-spetey-re-clains-free-will-and-conscious-freedom-20160814t111905211z'), format('Unexpected value of author_reward_operation.permlink: %s', op.permlink);
  ASSERT (select op.hbd_payout = '(138,3,@@000000013)'::hive.asset), format('Unexpected value of author_reward_operation.hbd_payout: %s', op.hbd_payout);
  ASSERT (select op.hive_payout = '(0,3,@@000000021)'::hive.asset), format('Unexpected value of author_reward_operation.hive_payout: %s', op.hive_payout);
  ASSERT (select op.vesting_payout = '(611497524,6,@@000000037)'::hive.asset), format('Unexpected value of author_reward_operation.vesting_payout: %s', op.vesting_payout);
  ASSERT (select op.curators_vesting_payout = '(395495911,6,@@000000037)'::hive.asset), format('Unexpected value of author_reward_operation.curators_vesting_payout: %s', op.curators_vesting_payout);
  ASSERT (select op.payout_must_be_claimed = False), format('Unexpected value of author_reward_operation.payout_must_be_claimed: %s', op.payout_must_be_claimed);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_changed_recovery_account_operation;
CREATE PROCEDURE check_operation_to_changed_recovery_account_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.changed_recovery_account_operation;
BEGIN
  op := '{"type": "changed_recovery_account_operation","value": {"account": "barrie","new_recovery_account": "boombastic_new","old_recovery_account": "boombastic_old"}}'::hive.operation::hive.changed_recovery_account_operation;
  ASSERT (select op.account = 'barrie'), format('Unexpected value of changed_recovery_account_operation.account: %s', op.account);
  ASSERT (select op.old_recovery_account = 'boombastic_old'), format('Unexpected value of changed_recovery_account_operation.old_recovery_account: %s', op.old_recovery_account);
  ASSERT (select op.new_recovery_account = 'boombastic_new'), format('Unexpected value of changed_recovery_account_operation.new_recovery_account: %s', op.new_recovery_account);
END;
$BODY$
;

DROP PROCEDURE IF EXISTS check_operation_to_clear_null_account_balance_operation;
CREATE PROCEDURE check_operation_to_clear_null_account_balance_operation()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
  op hive.clear_null_account_balance_operation;
BEGIN
  op := '{"type":"clear_null_account_balance_operation","value":{"total_cleared":[{"amount":"2000","precision":3,"nai":"@@000000021"},{"amount":"21702525","precision":3,"nai":"@@000000013"}]}}'::hive.operation::hive.clear_null_account_balance_operation;
  ASSERT (select op.total_cleared = '{"(2000,3,@@000000021)","(21702525,3,@@000000013)"}'::hive.asset[]), format('Unexpected value of clear_null_account_balance_operation.total_cleared: %s', op.total_cleared);
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
  CALL check_operation_to_comment_operation();
  CALL check_operation_to_comment_options_operation();
  CALL check_operation_to_vote_operation();
  CALL check_operation_to_witness_set_properties_operation();
  CALL check_operation_to_account_create_operation();
  CALL check_operation_to_account_create_with_delegation_operation();
  CALL check_operation_to_account_update2_operation();
  CALL check_operation_to_account_update_operation();
  CALL check_operation_to_account_witness_proxy_operation();
  CALL check_operation_to_account_witness_vote_operation();
  CALL check_operation_to_cancel_transfer_from_savings_operation();
  CALL check_operation_to_change_recovery_account_operation();
  CALL check_operation_to_claim_account_operation();
  CALL check_operation_to_claim_reward_balance_operation();
  CALL check_operation_to_collateralized_convert_operation();
  CALL check_operation_to_convert_operation();
  CALL check_operation_to_create_claimed_account_operation();
  CALL check_operation_to_custom_json_operation();
  CALL check_operation_to_custom_operation();
  CALL check_operation_to_decline_voting_rights_operation();
  CALL check_operation_to_delegate_vesting_shares_operation();
  CALL check_operation_to_delete_comment_operation();
  CALL check_operation_to_escrow_approve_operation();
  CALL check_operation_to_escrow_dispute_operation();
  CALL check_operation_to_escrow_release_operation();
  CALL check_operation_to_escrow_transfer_operation();
  CALL check_operation_to_feed_publish_operation();
  CALL check_operation_to_limit_order_cancel_operation();
  CALL check_operation_to_limit_order_create2_operation();
  CALL check_operation_to_limit_order_create_operation();
  CALL check_operation_to_pow2_operation();
  CALL check_operation_to_pow_operation();
  CALL check_operation_to_recover_account_operation();
  CALL check_operation_to_recurrent_transfer_operation();
  CALL check_operation_to_request_account_recovery_operation();
  CALL check_operation_to_set_withdraw_vesting_route_operation();
  CALL check_operation_to_transfer_from_savings_operation();
  CALL check_operation_to_transfer_operation();
  CALL check_operation_to_transfer_to_savings_operation();
  CALL check_operation_to_transfer_to_vesting_operation();
  CALL check_operation_to_withdraw_vesting_operation();
  CALL check_operation_to_witness_update_operation();
  CALL check_operation_to_create_proposal_operation();
  CALL check_operation_to_proposal_pay_operation();
  CALL check_operation_to_remove_proposal_operation();
  CALL check_operation_to_update_proposal_operation();
  CALL check_operation_to_update_proposal_votes_operation();
  CALL check_operation_to_account_created_operation();
  CALL check_operation_to_author_reward_operation();
  CALL check_operation_to_changed_recovery_account_operation();
  CALL check_operation_to_clear_null_account_balance_operation();
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


