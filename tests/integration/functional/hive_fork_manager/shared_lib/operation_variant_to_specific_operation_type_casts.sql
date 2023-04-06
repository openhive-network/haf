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


