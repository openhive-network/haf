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


