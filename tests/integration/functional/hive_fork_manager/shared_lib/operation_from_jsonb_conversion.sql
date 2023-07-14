CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
  ASSERT (SELECT '{"type":"system_warning_operation","value":{"message":""}}'::jsonb::hive.operation = '\x5200');

  ASSERT (SELECT '{"type":"system_warning_operation","value":{"message":"abc"}}'::jsonb::hive.operation = '\x5203616263');

  ASSERT (SELECT '{"type":"limit_order_cancel_operation","value":{"owner":"complexring","orderid":4294967295}}'::jsonb::hive.operation = '\x060b636f6d706c657872696e67ffffffff');

  ASSERT (SELECT '{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}'::jsonb::hive.operation = '\x52146e6f20696d706163746564206163636f756e7473');

  ASSERT (SELECT '{"type":"vote_operation","value":{"voter":"initminer","author":"alice","permlink":"permlink","weight":1000}}'::jsonb::hive.operation = '\x0009696e69746d696e657205616c696365087065726d6c696e6be803');

  ASSERT (SELECT '{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"someone","author":"bob","permlink":"test-permlink","title":"test-title","body":"this is a body","json_metadata":"{}"}}'::jsonb::hive.operation = '\x010007736f6d656f6e6503626f620d746573742d7065726d6c696e6b0a746573742d7469746c650e74686973206973206120626f6479027b7d');

  ASSERT (SELECT '{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"10000","precision":3,"nai":"@@000000021"},"memo":"memo"}}'::jsonb::hive.operation = '\x0209696e69746d696e657205616c696365102700000000000003535445454d0000046d656d6f');

  ASSERT (SELECT '{"type":"limit_order_create_operation","value":{"owner":"alice","orderid":1000,"amount_to_sell":{"amount":"1000","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"1000","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2023-01-02T11:43:07"}}'::jsonb::hive.operation = '\x0505616c696365e8030000e80300000000000003535445454d0000e8030000000000000353424400000000004bc3b263');

  ASSERT (SELECT '{"type":"limit_order_cancel_operation","value":{"owner":"alice","orderid":1}}'::jsonb::hive.operation = '\x0605616c69636501000000');

  ASSERT (SELECT '{"type":"feed_publish_operation","value":{"publisher":"initminer","exchange_rate":{"base":{"amount":"1","precision":3,"nai":"@@000000013"},"quote":{"amount":"1","precision":3,"nai":"@@000000021"}}}}'::jsonb::hive.operation = '\x0709696e69746d696e657201000000000000000353424400000000010000000000000003535445454d0000');

  ASSERT (SELECT '{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"dan","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"memo_key":"STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH","json_metadata":"{}"}}'::jsonb::hive.operation = '\x09000000000000000003535445454d000009696e69746d696e65720364616e010000000001028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b00100010000000001028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b00100010000000001028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b00100028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b0027b7d');

  ASSERT (SELECT '{"type":"account_update_operation","value":{"account":"alice","memo_key":"STM7DfRjPa69TUwmvqU7igeKDLf2pwUaF2CHpd7oeHUSYpjwkVhE8","json_metadata":"{}"}}'::jsonb::hive.operation = '\x0a05616c6963650000000332edaa6d50c9d47dc51e819e9b00f3640a8c47f544996044881f7e43bcce523e027b7d');

  ASSERT (SELECT '{"type":"witness_update_operation","value":{"owner":"alice","url":"http://url.html","block_signing_key":"STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW","props":{"account_creation_fee":{"amount":"10000" ,"precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}'::jsonb::hive.operation = '\x0b05616c6963650f687474703a2f2f75726c2e68746d6c02410be8f7ca66c250f420a07382ba23af572c98f5fc825ce73d24b7ace17e0e6d102700000000000003535445454d000000000200e803000000000000000003535445454d0000');

  ASSERT (SELECT '{"type":"account_witness_vote_operation","value":{"account":"alice","witness":"initminer","approve":true}}'::jsonb::hive.operation = '\x0c05616c69636509696e69746d696e657201');

  ASSERT (SELECT '{"type":"account_witness_proxy_operation","value":{"account":"initminer","proxy":"alice"}}'::jsonb::hive.operation = '\x0d09696e69746d696e657205616c696365');

  ASSERT (SELECT '{
  "type": "pow_operation",
  "value": {
    "block_id": "002104af55d5c492c8c134b5a55c89eac8210a86",
    "nonce": "6317456790497374569",
    "props": {
      "account_creation_fee": {
        "amount": "1",
        "nai": "@@000000021",
        "precision": 3
      },
      "hbd_interest_rate": 1000,
      "maximum_block_size": 131072
    },
    "work": {
      "input": "d28a6c6f0fd04548ef12833d3e95acf7690cfb2bc6f6c8cd3b277d2f234bd908",
      "signature": "20bd759200fb6996e141f1968beb3ef7d37a1692f15dc3a6c930388b27ec8691c07e36d3a0f441de10d12b2b1c98ed0816d3c2dfe1c8be1eacfd27fe5f4dd7f07a",
      "work": "0000000c822c37f6a18985b1ef0eac34ae51f9e87d9ce3a8a217c90c7d74d82e",
      "worker": "STM5DHtHTDTyr3A4uutu6EsnHPfxAfRo9gQoJRT7jAHw4eU4UWRCK"
    },
    "worker_account": "badger3143"
  }
}'::jsonb::hive.operation = '\x0e0a62616467657233313433002104af55d5c492c8c134b5a55c89eac8210a8669b179c97a1dac57022ab15e2aaa3fe83aefeecafe153d10e182c29cd6a3c29d673ac183a86820b611d28a6c6f0fd04548ef12833d3e95acf7690cfb2bc6f6c8cd3b277d2f234bd90820bd759200fb6996e141f1968beb3ef7d37a1692f15dc3a6c930388b27ec8691c07e36d3a0f441de10d12b2b1c98ed0816d3c2dfe1c8be1eacfd27fe5f4dd7f07a0000000c822c37f6a18985b1ef0eac34ae51f9e87d9ce3a8a217c90c7d74d82e010000000000000003535445454d000000000200e803');

  ASSERT (SELECT '{"type": "custom_operation","value": {"data": "0a","id": 777,"required_auths": ["bytemaster"]}}'::jsonb::hive.operation = '\x0f010a627974656d61737465720903010a');

  ASSERT (SELECT '{"type": "delete_comment_operation","value": {"author": "camilla","permlink": "re-shenanigator"}}'::jsonb::hive.operation = '\x110763616d696c6c610f72652d7368656e616e696761746f72');

  ASSERT (SELECT '{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["alice"],"id":"follow","json":"{\"type\":\"follow_operation\",\"value\":{\"follower\":\"alice\",\"following\":\"@bob\",\"what\":[\"blog\"]}}"}}'::jsonb::hive.operation = '\x12000105616c69636506666f6c6c6f775b7b2274797065223a22666f6c6c6f775f6f7065726174696f6e222c2276616c7565223a7b22666f6c6c6f776572223a22616c696365222c22666f6c6c6f77696e67223a2240626f62222c2277686174223a5b22626c6f67225d7d7d');

  ASSERT (SELECT '{
  "type": "comment_options_operation",
  "value": {
    "allow_curation_rewards": true,
    "allow_votes": true,
    "author": "djangothegod",
    "extensions": [],
    "max_accepted_payout": {
      "amount": "1000000000",
      "nai": "@@000000013",
      "precision": 3
    },
    "percent_hbd": 0,
    "permlink": "i-did-mean-it-in-no-bad-way"
  }
}'::jsonb::hive.operation = '\x130c646a616e676f746865676f641b692d6469642d6d65616e2d69742d696e2d6e6f2d6261642d77617900ca9a3b0000000003534244000000000000010100');

  ASSERT (SELECT '{"type":"set_withdraw_vesting_route_operation","value":{"from_account":"alice","to_account":"bob","percent":30,"auto_vest":true}}'::jsonb::hive.operation = '\x1405616c69636503626f621e0001');

  ASSERT (SELECT '{"type":"claim_account_operation","value":{"creator":"initminer","fee":{"amount":"0","precision":3,"nai":"@@000000021"},"extensions":[]}}'::jsonb::hive.operation = '\x1609696e69746d696e6572000000000000000003535445454d000000');

  ASSERT (SELECT '{"type":"request_account_recovery_operation","value":{"recovery_account":"initminer","account_to_recover":"alice","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW",1]]},"extensions":[]}}'::jsonb::hive.operation = '\x1809696e69746d696e657205616c69636501000000000102410be8f7ca66c250f420a07382ba23af572c98f5fc825ce73d24b7ace17e0e6d010000');

  ASSERT (SELECT '{"type":"recover_account_operation","value":{"account_to_recover":"alice","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6LLegbAgLAy28EHrffBVuANFWcFgmqRMW13wBmTExqFE9SCkg4",1]]},"recent_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW",1]]},"extensions":[]}}'::jsonb::hive.operation = '\x1905616c69636501000000000102be643d4c424ac7cf2f3cf51dd048773cbdcee30b111adb30d89c27668c501705010001000000000102410be8f7ca66c250f420a07382ba23af572c98f5fc825ce73d24b7ace17e0e6d010000');

  ASSERT (SELECT '{"type":"change_recovery_account_operation","value":{"account_to_recover":"initminer","new_recovery_account":"alice","extensions":[]}}'::jsonb::hive.operation = '\x1a09696e69746d696e657205616c69636500');

  ASSERT (SELECT '{"type":"escrow_transfer_operation","value":{"from":"initminer","to":"alice","hbd_amount":{"amount":"10000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"10000","precision":3,"nai":"@@000000021"},"escrow_id":10,"agent":"bob","fee":{"amount":"10000","precision":3,"nai":"@@000000013"},"json_meta":"{}","ratification_deadline":"2030-01-01T00:00:00","escrow_expiration":"2030-06-01T00:00:00"}}'::jsonb::hive.operation = '\x1b09696e69746d696e657205616c69636510270000000000000353424400000000102700000000000003535445454d00000a00000003626f6210270000000000000353424400000000027b7d80d8db7000eba271');

  ASSERT (SELECT '{"type":"escrow_dispute_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"initminer","escrow_id":3}}'::jsonb::hive.operation = '\x1c09696e69746d696e657205616c69636503626f6209696e69746d696e657203000000');

  ASSERT (SELECT '{"type":"escrow_release_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"bob","receiver":"alice","escrow_id":1,"hbd_amount":{"amount":"10000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"10000","precision":3,"nai":"@@000000021"}}}'::jsonb::hive.operation = '\x1d09696e69746d696e657205616c69636503626f6203626f6205616c6963650100000010270000000000000353424400000000102700000000000003535445454d0000');

  ASSERT (SELECT '{
  "type": "pow2_operation",
  "value": {
    "props": {
      "account_creation_fee": {
        "amount": "1",
        "nai": "@@000000021",
        "precision": 3
      },
      "hbd_interest_rate": 1000,
      "maximum_block_size": 131072
    },
    "work": {
      "type": "pow2",
      "value": {
        "input": {
          "nonce": "2363830237862599931",
          "prev_block": "003ead0c90b0cd80e9145805d303957015c50ef1",
          "worker_account": "thedao"
        },
        "pow_summary": 3878270667
      }
    }
  }
}'::jsonb::hive.operation = '\x1e000674686564616f003ead0c90b0cd80e9145805d303957015c50ef1fb9c20c51303ce20cbb629e700010000000000000003535445454d000000000200e803');

  ASSERT (SELECT '{"type":"escrow_approve_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"bob","escrow_id":2,"approve":true}}'::jsonb::hive.operation = '\x1f09696e69746d696e657205616c69636503626f6203626f620200000001');

  ASSERT (SELECT '{"type":"transfer_to_savings_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"100000","precision":3,"nai":"@@000000021"},"memo":"memo"}}'::jsonb::hive.operation = '\x2009696e69746d696e657205616c696365a08601000000000003535445454d0000046d656d6f');

  ASSERT (SELECT '{"type":"transfer_from_savings_operation","value":{"from":"alice","request_id":1000,"to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"memo"}}'::jsonb::hive.operation = '\x2105616c696365e803000003626f62e80300000000000003535445454d0000046d656d6f');

  ASSERT (SELECT '{"type":"cancel_transfer_from_savings_operation","value":{"from":"alice","request_id":1}}'::jsonb::hive.operation = '\x2205616c69636501000000');

  ASSERT (SELECT '{"type":"decline_voting_rights_operation","value":{"account":"initminer","decline":true}}'::jsonb::hive.operation = '\x2409696e69746d696e657201');

  ASSERT (SELECT '{"type":"delegate_vesting_shares_operation","value":{"delegator":"alice","delegatee":"bob","vesting_shares":{"amount":"1000000","precision":6,"nai":"@@000000037"}}}'::jsonb::hive.operation = '\x2805616c69636503626f6240420f00000000000656455354530000');

  ASSERT (SELECT '{"type":"create_proposal_operation","value":{"creator":"alice","receiver":"alice","start_date":"2031-01-01T00:00:00","end_date":"2031-06-01T00:00:00","daily_pay":{"amount":"1000000","precision":3,"nai":"@@000000013"},"subject":"subject-1","permlink":"permlink","extensions":[]}}'::jsonb::hive.operation = '\x2c05616c69636505616c696365000cbd72801e847340420f00000000000353424400000000097375626a6563742d31087065726d6c696e6b00');

  ASSERT (SELECT '{"type":"update_proposal_votes_operation","value":{"voter":"alice","proposal_ids":[0, 1, 2],"approve":true,"extensions":[]}}'::jsonb::hive.operation = '\x2d05616c696365030000000000000000010000000000000002000000000000000100');

  ASSERT (SELECT '{"type":"remove_proposal_operation","value":{"proposal_owner":"initminer","proposal_ids":[7],"extensions":[]}}'::jsonb::hive.operation = '\x2e09696e69746d696e657201070000000000000000');

  ASSERT (SELECT '{"type":"update_proposal_operation","value":{"proposal_id":0,"creator":"alice","daily_pay":{"amount":"10000","precision":3,"nai":"@@000000013"},"subject":"subject-1","permlink":"permlink","extensions":[{"type":"update_proposal_end_date","value":{"end_date":"2031-05-01T00:00:00"}}]}}'::jsonb::hive.operation = '\x2f000000000000000005616c69636510270000000000000353424400000000097375626a6563742d31087065726d6c696e6b010100405b73');

  ASSERT (SELECT '{"type":"recurrent_transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"memo","recurrence":720,"executions":12,"extensions":[]}}'::jsonb::hive.operation = '\x3105616c69636503626f62881300000000000003535445454d0000046d656d6fd0020c0000');

BEGIN
  PERFORM '{}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation cannot be created from an empty object';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"system_warning_operation","value":{"message":[]}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created from json with incorrect message field';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"limit_order_cancel_operation","value":{"owner":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","orderid":1}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created because name is too long';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":10000,"precision":3,"nai":"@@000000021"},"memo":"memo"}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created because amount needs to be a string';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"-1","precision":3,"nai":"@@000000021"},"memo":"memo"}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created because amount cannot be negative';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"10000","precision":"3","nai":"@@000000021"},"memo":"memo"}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created because precision needs to be an integer';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"10000","precision":3,"nai":"@@000000020"},"memo":"memo"}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created because nai is incorrect';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"update_proposal_votes_operation","value":{"voter":"alice","proposal_ids":[0,1,5,3],"approve":true,"extensions":[]}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created because proposals ids are not increasing';
EXCEPTION WHEN invalid_text_representation THEN
END;

BEGIN
  PERFORM '{"type":"update_proposal_votes_operation","value":{"voter":"alice","proposal_ids":[0,1,1],"approve":true,"extensions":[]}}'::jsonb::hive.operation;
  RAISE EXCEPTION 'Operation should not be created because proposals ids are not unique';
EXCEPTION WHEN invalid_text_representation THEN
END;

END;
$BODY$
;
