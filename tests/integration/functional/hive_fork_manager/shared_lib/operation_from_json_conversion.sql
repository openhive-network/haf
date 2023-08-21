DROP FUNCTION IF EXISTS ASSERT_THIS_TEST;
CREATE FUNCTION ASSERT_THIS_TEST(op TEXT, bytes TEXT)
    RETURNS void
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  -- Make sure that both conversions produce the same value
  ASSERT (SELECT hive.operation_from_jsontext(op)::TEXT = bytes);
  ASSERT (SELECT op::JSONB::hive.operation::TEXT = bytes);
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":""}}',
    '\x5200');
  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":"abc"}}',
    '\x5203616263');
  PERFORM ASSERT_THIS_TEST('{"type":"limit_order_cancel_operation","value":{"owner":"complexring","orderid":4294967295}}',
    '\x060b636f6d706c657872696e67ffffffff');
  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}',
    '\x52146e6f20696d706163746564206163636f756e7473');
  PERFORM ASSERT_THIS_TEST('{
    "type": "pow_operation",
    "value": {
        "work": {
            "work": "000000049711861bce6185671b672696eca64398586a66319eacd875155b77fc",
            "input": "c55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b",
            "worker": "STM6tC4qRjUPKmkqkug5DvSgkeND5DHhnfr3XTgpp4b4nejMEwn9k",
            "signature": "1fbce97f375ac58c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81a00"
        },
        "nonce": 42,
        "props": {
            "hbd_interest_rate": 1000,
            "maximum_block_size": 131072,
            "account_creation_fee": {
                "nai": "@@000000021",
                "amount": "100000",
                "precision": 3
            }
        },
        "block_id": "00015d56d6e721ede5aad1babb0fe818203cbeeb",
        "worker_account": "sminer10"
    }
  }',
  '\x0e08736d696e6572313000015d56d6e721ede5aad1babb0fe818203cbeeb2a000000000000000306b7270831d7e89a5d2b23ba614e6af9f587d2916cbd8f5fd736faa08acdda1ac55811a1a9cf6a281acad3aba38223027158186cfd280c41fffe5e2b0d2d6e0b1fbce97f375ac58c185905ac8e44a9c8b50b7e618bf4a7559816d8316e3b09ff54da096c2f5eddcca1229cf0b9da9597eac2ae676e424bdb432a7855295cd81a00000000049711861bce6185671b672696eca64398586a66319eacd875155b77fca08601000000000003535445454d000000000200e803');

  BEGIN
    PERFORM hive.operation_from_jsontext('{}');
    RAISE EXCEPTION 'Operation cannot be created from an empty object';
  EXCEPTION WHEN invalid_text_representation THEN
  END;

  BEGIN
    PERFORM hive.operation_from_jsontext('{"type":"system_warning_operation","value":{"message":[]}}');
    RAISE EXCEPTION 'Operation should not be created from json with incorrect message field';
  EXCEPTION WHEN invalid_text_representation THEN
  END;

  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":""}}',
    '\x5200');
  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":"abc"}}',
    '\x5203616263');
  PERFORM ASSERT_THIS_TEST('{"type":"limit_order_cancel_operation","value":{"owner":"complexring","orderid":4294967295}}',
    '\x060b636f6d706c657872696e67ffffffff');
  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":"no impacted accounts"}}',
    '\x52146e6f20696d706163746564206163636f756e7473');
  PERFORM ASSERT_THIS_TEST('{"type":"vote_operation","value":{"voter":"initminer","author":"alice","permlink":"permlink","weight":1000}}',
    '\x0009696e69746d696e657205616c696365087065726d6c696e6be803');
  PERFORM ASSERT_THIS_TEST('{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"someone","author":"bob","permlink":"test-permlink","title":"test-title","body":"this is a body","json_metadata":"{}"}}',
    '\x010007736f6d656f6e6503626f620d746573742d7065726d6c696e6b0a746573742d7469746c650e74686973206973206120626f6479027b7d');
  PERFORM ASSERT_THIS_TEST('{"type":"transfer_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"10000","precision":3,"nai":"@@000000021"},"memo":"memo"}}',
    '\x0209696e69746d696e657205616c696365102700000000000003535445454d0000046d656d6f');
  PERFORM ASSERT_THIS_TEST('{"type":"limit_order_create_operation","value":{"owner":"alice","orderid":1000,"amount_to_sell":{"amount":"1000","precision":3,"nai":"@@000000021"},"min_to_receive":{"amount":"1000","precision":3,"nai":"@@000000013"},"fill_or_kill":false,"expiration":"2023-01-02T11:43:07"}}',
    '\x0505616c696365e8030000e80300000000000003535445454d0000e8030000000000000353424400000000004bc3b263');
  PERFORM ASSERT_THIS_TEST('{"type":"limit_order_cancel_operation","value":{"owner":"alice","orderid":1}}',
    '\x0605616c69636501000000');
  PERFORM ASSERT_THIS_TEST('{"type":"feed_publish_operation","value":{"publisher":"initminer","exchange_rate":{"base":{"amount":"1","precision":3,"nai":"@@000000013"},"quote":{"amount":"1","precision":3,"nai":"@@000000021"}}}}',
    '\x0709696e69746d696e657201000000000000000353424400000000010000000000000003535445454d0000');
  PERFORM ASSERT_THIS_TEST('{"type":"account_create_operation","value":{"fee":{"amount":"0","precision":3,"nai":"@@000000021"},"creator":"initminer","new_account_name":"dan","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH",1]]},"memo_key":"STM5vYywCazmCT3XSRhxoPPHEznNJqQHzSDnGsGYTKR6VkU88E1gH","json_metadata":"{}"}}',
    '\x09000000000000000003535445454d000009696e69746d696e65720364616e010000000001028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b00100010000000001028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b00100010000000001028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b00100028861208bc91fb754c2a7d88ebc945289bf310093c548b1f2d8365c7e103653b0027b7d');
  PERFORM ASSERT_THIS_TEST('{"type":"account_update_operation","value":{"account":"alice","memo_key":"STM7DfRjPa69TUwmvqU7igeKDLf2pwUaF2CHpd7oeHUSYpjwkVhE8","json_metadata":"{}"}}',
    '\x0a05616c6963650000000332edaa6d50c9d47dc51e819e9b00f3640a8c47f544996044881f7e43bcce523e027b7d');
  PERFORM ASSERT_THIS_TEST('{"type":"witness_update_operation","value":{"owner":"alice","url":"http://url.html","block_signing_key":"STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW","props":{"account_creation_fee":{"amount":"10000" ,"precision":3,"nai":"@@000000021"},"maximum_block_size":131072,"hbd_interest_rate":1000},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}',
    '\x0b05616c6963650f687474703a2f2f75726c2e68746d6c02410be8f7ca66c250f420a07382ba23af572c98f5fc825ce73d24b7ace17e0e6d102700000000000003535445454d000000000200e803000000000000000003535445454d0000');
  PERFORM ASSERT_THIS_TEST('{"type":"account_witness_vote_operation","value":{"account":"alice","witness":"initminer","approve":true}}',
    '\x0c05616c69636509696e69746d696e657201');
  PERFORM ASSERT_THIS_TEST('{"type":"account_witness_proxy_operation","value":{"account":"initminer","proxy":"alice"}}',
    '\x0d09696e69746d696e657205616c696365');
  PERFORM ASSERT_THIS_TEST('{
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
  }',
  '\x0e0a62616467657233313433002104af55d5c492c8c134b5a55c89eac8210a8669b179c97a1dac57022ab15e2aaa3fe83aefeecafe153d10e182c29cd6a3c29d673ac183a86820b611d28a6c6f0fd04548ef12833d3e95acf7690cfb2bc6f6c8cd3b277d2f234bd90820bd759200fb6996e141f1968beb3ef7d37a1692f15dc3a6c930388b27ec8691c07e36d3a0f441de10d12b2b1c98ed0816d3c2dfe1c8be1eacfd27fe5f4dd7f07a0000000c822c37f6a18985b1ef0eac34ae51f9e87d9ce3a8a217c90c7d74d82e010000000000000003535445454d000000000200e803');
  PERFORM ASSERT_THIS_TEST('{"type": "custom_operation","value": {"data": "0a","id": 777,"required_auths": ["bytemaster"]}}',
    '\x0f010a627974656d61737465720903010a');
  PERFORM ASSERT_THIS_TEST('{"type": "delete_comment_operation","value": {"author": "camilla","permlink": "re-shenanigator"}}',
    '\x110763616d696c6c610f72652d7368656e616e696761746f72');
  PERFORM ASSERT_THIS_TEST('{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["alice"],"id":"follow","json":"{\"type\":\"follow_operation\",\"value\":{\"follower\":\"alice\",\"following\":\"@bob\",\"what\":[\"blog\"]}}"}}',
    '\x12000105616c69636506666f6c6c6f775b7b2274797065223a22666f6c6c6f775f6f7065726174696f6e222c2276616c7565223a7b22666f6c6c6f776572223a22616c696365222c22666f6c6c6f77696e67223a2240626f62222c2277686174223a5b22626c6f67225d7d7d');
  PERFORM ASSERT_THIS_TEST('{
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
  }',
  '\x130c646a616e676f746865676f641b692d6469642d6d65616e2d69742d696e2d6e6f2d6261642d77617900ca9a3b0000000003534244000000000000010100');
  PERFORM ASSERT_THIS_TEST('{"type":"set_withdraw_vesting_route_operation","value":{"from_account":"alice","to_account":"bob","percent":30,"auto_vest":true}}',
    '\x1405616c69636503626f621e0001');
  PERFORM ASSERT_THIS_TEST('{"type":"claim_account_operation","value":{"creator":"initminer","fee":{"amount":"0","precision":3,"nai":"@@000000021"},"extensions":[]}}',
    '\x1609696e69746d696e6572000000000000000003535445454d000000');
  PERFORM ASSERT_THIS_TEST('{"type":"request_account_recovery_operation","value":{"recovery_account":"initminer","account_to_recover":"alice","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW",1]]},"extensions":[]}}',
    '\x1809696e69746d696e657205616c69636501000000000102410be8f7ca66c250f420a07382ba23af572c98f5fc825ce73d24b7ace17e0e6d010000');
  PERFORM ASSERT_THIS_TEST('{"type":"recover_account_operation","value":{"account_to_recover":"alice","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6LLegbAgLAy28EHrffBVuANFWcFgmqRMW13wBmTExqFE9SCkg4",1]]},"recent_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW",1]]},"extensions":[]}}',
    '\x1905616c69636501000000000102be643d4c424ac7cf2f3cf51dd048773cbdcee30b111adb30d89c27668c501705010001000000000102410be8f7ca66c250f420a07382ba23af572c98f5fc825ce73d24b7ace17e0e6d010000');
  PERFORM ASSERT_THIS_TEST('{"type":"change_recovery_account_operation","value":{"account_to_recover":"initminer","new_recovery_account":"alice","extensions":[]}}',
    '\x1a09696e69746d696e657205616c69636500');
  PERFORM ASSERT_THIS_TEST('{"type":"escrow_transfer_operation","value":{"from":"initminer","to":"alice","hbd_amount":{"amount":"10000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"10000","precision":3,"nai":"@@000000021"},"escrow_id":10,"agent":"bob","fee":{"amount":"10000","precision":3,"nai":"@@000000013"},"json_meta":"{}","ratification_deadline":"2030-01-01T00:00:00","escrow_expiration":"2030-06-01T00:00:00"}}',
    '\x1b09696e69746d696e657205616c69636510270000000000000353424400000000102700000000000003535445454d00000a00000003626f6210270000000000000353424400000000027b7d80d8db7000eba271');
  PERFORM ASSERT_THIS_TEST('{"type":"escrow_dispute_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"initminer","escrow_id":3}}',
    '\x1c09696e69746d696e657205616c69636503626f6209696e69746d696e657203000000');
  PERFORM ASSERT_THIS_TEST('{"type":"escrow_release_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"bob","receiver":"alice","escrow_id":1,"hbd_amount":{"amount":"10000","precision":3,"nai":"@@000000013"},"hive_amount":{"amount":"10000","precision":3,"nai":"@@000000021"}}}',
    '\x1d09696e69746d696e657205616c69636503626f6203626f6205616c6963650100000010270000000000000353424400000000102700000000000003535445454d0000');
  PERFORM ASSERT_THIS_TEST('{
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
  }',
'\x1e000674686564616f003ead0c90b0cd80e9145805d303957015c50ef1fb9c20c51303ce20cbb629e700010000000000000003535445454d000000000200e803');
  PERFORM ASSERT_THIS_TEST('{"type":"escrow_approve_operation","value":{"from":"initminer","to":"alice","agent":"bob","who":"bob","escrow_id":2,"approve":true}}',
    '\x1f09696e69746d696e657205616c69636503626f6203626f620200000001');
  PERFORM ASSERT_THIS_TEST('{"type":"transfer_to_savings_operation","value":{"from":"initminer","to":"alice","amount":{"amount":"100000","precision":3,"nai":"@@000000021"},"memo":"memo"}}',
    '\x2009696e69746d696e657205616c696365a08601000000000003535445454d0000046d656d6f');
  PERFORM ASSERT_THIS_TEST('{"type":"transfer_from_savings_operation","value":{"from":"alice","request_id":1000,"to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":"memo"}}',
    '\x2105616c696365e803000003626f62e80300000000000003535445454d0000046d656d6f');
  PERFORM ASSERT_THIS_TEST('{"type":"cancel_transfer_from_savings_operation","value":{"from":"alice","request_id":1}}',
    '\x2205616c69636501000000');
  PERFORM ASSERT_THIS_TEST('{"type":"decline_voting_rights_operation","value":{"account":"initminer","decline":true}}',
    '\x2409696e69746d696e657201');
  PERFORM ASSERT_THIS_TEST('{"type":"delegate_vesting_shares_operation","value":{"delegator":"alice","delegatee":"bob","vesting_shares":{"amount":"1000000","precision":6,"nai":"@@000000037"}}}',
    '\x2805616c69636503626f6240420f00000000000656455354530000');
  PERFORM ASSERT_THIS_TEST('{"type":"create_proposal_operation","value":{"creator":"alice","receiver":"alice","start_date":"2031-01-01T00:00:00","end_date":"2031-06-01T00:00:00","daily_pay":{"amount":"1000000","precision":3,"nai":"@@000000013"},"subject":"subject-1","permlink":"permlink","extensions":[]}}',
    '\x2c05616c69636505616c696365000cbd72801e847340420f00000000000353424400000000097375626a6563742d31087065726d6c696e6b00');
  PERFORM ASSERT_THIS_TEST('{"type":"update_proposal_votes_operation","value":{"voter":"alice","proposal_ids":[0, 1, 2],"approve":true,"extensions":[]}}',
    '\x2d05616c696365030000000000000000010000000000000002000000000000000100');
  PERFORM ASSERT_THIS_TEST('{"type":"remove_proposal_operation","value":{"proposal_owner":"initminer","proposal_ids":[7],"extensions":[]}}',
    '\x2e09696e69746d696e657201070000000000000000');
  PERFORM ASSERT_THIS_TEST('{"type":"update_proposal_operation","value":{"proposal_id":0,"creator":"alice","daily_pay":{"amount":"10000","precision":3,"nai":"@@000000013"},"subject":"subject-1","permlink":"permlink","extensions":[{"type":"update_proposal_end_date","value":{"end_date":"2031-05-01T00:00:00"}}]}}',
    '\x2f000000000000000005616c69636510270000000000000353424400000000097375626a6563742d31087065726d6c696e6b010100405b73');
  PERFORM ASSERT_THIS_TEST('{"type":"recurrent_transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"5000","precision":3,"nai":"@@000000021"},"memo":"memo","recurrence":720,"executions":12,"extensions":[]}}',
    '\x3105616c69636503626f62881300000000000003535445454d0000046d656d6fd0020c0000');

  -- virtual operations:

  PERFORM ASSERT_THIS_TEST('{
    "type": "fill_convert_request_operation",
    "value": {
      "amount_in": {
        "amount": "2000000",
        "nai": "@@000000013",
        "precision": 3
      },
      "amount_out": {
        "amount": "605143",
        "nai": "@@000000021",
        "precision": 3
      },
      "owner": "xeroc",
      "requestid": 1468315395
    }
  }',
  '\x32057865726f6303b7845780841e00000000000353424400000000d73b09000000000003535445454d0000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "author_reward_operation",
    "value": {
      "author": "xeroc",
      "curators_vesting_payout": {
        "amount": "0",
        "nai": "@@000000037",
        "precision": 6
      },
      "hbd_payout": {
        "amount": "21",
        "nai": "@@000000013",
        "precision": 3
      },
      "hive_payout": {
        "amount": "0",
        "nai": "@@000000021",
        "precision": 3
      },
      "permlink": "this-piston-rocks-public-steem-steem-api-for-piston-users-and-developers",
      "vesting_payout": {
        "amount": "29859881",
        "nai": "@@000000037",
        "precision": 6
      }
    }
  }',
  '\x33057865726f6348746869732d706973746f6e2d726f636b732d7075626c69632d737465656d2d737465656d2d6170692d666f722d706973746f6e2d75736572732d616e642d646576656c6f7065727315000000000000000353424400000000000000000000000003535445454d000029a0c7010000000006564553545300000000000000000000065645535453000000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "curation_reward_operation",
    "value": {
      "comment_author": "anca3drandom",
      "comment_permlink": "steemart-the-art-of-quilling-paper-steemit-logo",
      "curator": "camilla",
      "payout_must_be_claimed": false,
      "reward": {
        "amount": "80336806",
        "nai": "@@000000037",
        "precision": 6
      }
    }
  }',
  '\x340763616d696c6c61a6d7c9040000000006564553545300000c616e6361336472616e646f6d2f737465656d6172742d7468652d6172742d6f662d7175696c6c696e672d70617065722d737465656d69742d6c6f676f00');

  PERFORM ASSERT_THIS_TEST('{
    "type": "comment_reward_operation",
    "value": {
      "author": "xeroc",
      "author_rewards": 13,
      "beneficiary_payout_value": {
        "amount": "0",
        "nai": "@@000000013",
        "precision": 3
      },
      "curator_payout_value": {
        "amount": "388196",
        "nai": "@@000000013",
        "precision": 3
      },
      "payout": {
        "amount": "45",
        "nai": "@@000000013",
        "precision": 3
      },
      "permlink": "this-piston-rocks-public-steem-steem-api-for-piston-users-and-developers",
      "total_payout_value": {
        "amount": "967021",
        "nai": "@@000000013",
        "precision": 3
      }
    }
  }',
  '\x35057865726f6348746869732d706973746f6e2d726f636b732d7075626c69632d737465656d2d737465656d2d6170692d666f722d706973746f6e2d75736572732d616e642d646576656c6f706572732d0000000000000003534244000000000d000000000000006dc10e0000000000035342440000000064ec050000000000035342440000000000000000000000000353424400000000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "liquidity_reward_operation",
    "value": {
      "owner": "adm",
      "payout": {
        "amount": "1200000",
        "nai": "@@000000021",
        "precision": 3
      }
    }
  }',
  '\x360361646d804f12000000000003535445454d0000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "interest_operation",
    "value": {
      "interest": {
        "amount": "247",
        "nai": "@@000000013",
        "precision": 3
      },
      "owner": "xeroc"
    }
  }',
  '\x37057865726f63f700000000000000035342440000000000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "fill_vesting_withdraw_operation",
    "value": {
      "deposited": {
        "amount": "26",
        "nai": "@@000000021",
        "precision": 3
      },
      "from_account": "bu328118",
      "to_account": "bu328118",
      "withdrawn": {
        "amount": "89319545",
        "nai": "@@000000037",
        "precision": 6
      }
    }
  }',
  '\x3808627533323831313808627533323831313879e852050000000006564553545300001a0000000000000003535445454d0000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "fill_order_operation",
    "value": {
      "current_orderid": 10,
      "current_owner": "ledzeppelin",
      "current_pays": {
        "amount": "1088582",
        "nai": "@@000000013",
        "precision": 3
      },
      "open_orderid": 2454834171,
      "open_owner": "adm",
      "open_pays": {
        "amount": "385205",
        "nai": "@@000000021",
        "precision": 3
      }
    }
  }',
  '\x390b6c65647a657070656c696e0a000000469c10000000000003534244000000000361646dfbcb5192b5e005000000000003535445454d0000');

  PERFORM ASSERT_THIS_TEST('{"type":"hardfork_operation","value":{"hardfork_id":7}}',
    '\x3c07000000');
  PERFORM ASSERT_THIS_TEST('{"type":"comment_payout_update_operation","value":{"author":"fatima992002","permlink":"thev-new-germanic-medicine"}}',
    '\x3d0c666174696d613939323030321a746865762d6e65772d6765726d616e69632d6d65646963696e65');

  PERFORM ASSERT_THIS_TEST('{
    "type": "producer_reward_operation",
    "value": {
      "producer": "leigh",
      "vesting_shares": {
        "amount": "14928815403",
        "nai": "@@000000037",
        "precision": 6
      }
    }
  }',
  '\x40056c656967682ba5d379030000000656455354530000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "effective_comment_vote_operation",
    "value": {
      "author": "watchonline",
      "pending_payout": {
        "amount": "3",
        "nai": "@@000000013",
        "precision": 3
      },
      "permlink": "suicide-squad-2016-watch-full-movie-stream-online-free",
      "rshares": 59675015,
      "total_vote_weight": 0,
      "voter": "massmindrape",
      "weight": 0
    }
  }',
  '\x480c6d6173736d696e64726170650b77617463686f6e6c696e6536737569636964652d73717561642d323031362d77617463682d66756c6c2d6d6f7669652d73747265616d2d6f6e6c696e652d66726565000000000000000087918e0300000000000000000000000003000000000000000353424400000000');

  PERFORM ASSERT_THIS_TEST('{"type":"ineffective_delete_comment_operation","value":{"author":"jsc","permlink":"just-test-20160603t163718014z"}}',
    '\x49036a73631d6a7573742d746573742d3230313630363033743136333731383031347a');

  PERFORM ASSERT_THIS_TEST('{
    "type": "changed_recovery_account_operation",
    "value": {
      "account": "barrie",
      "new_recovery_account": "boombastic",
      "old_recovery_account": "steem"
    }
  }',
  '\x4c0662617272696505737465656d0a626f6f6d626173746963');

  PERFORM ASSERT_THIS_TEST('{
    "type": "transfer_to_vesting_completed_operation",
    "value": {
      "from_account": "blocktrades",
      "hive_vested": {
        "amount": "691177",
        "nai": "@@000000021",
        "precision": 3
      },
      "to_account": "kripto",
      "vesting_shares_received": {
        "amount": "2237516892686",
        "nai": "@@000000037",
        "precision": 6
      }
    }
  }',
  '\x4d0b626c6f636b747261646573066b726970746fe98b0a000000000003535445454d00000e4a66f6080200000656455354530000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "pow_reward_operation",
    "value": {
      "reward": {
        "amount": "6003711911",
        "nai": "@@000000037",
        "precision": 6
      },
      "worker": "dele-puppy"
    }
  }',
  '\x4e0a64656c652d7075707079a75fd965010000000656455354530000');

  PERFORM ASSERT_THIS_TEST('{
    "type": "account_created_operation",
    "value": {
      "creator": "steem",
      "initial_delegation": {
        "amount": "0",
        "nai": "@@000000037",
        "precision": 6
      },
      "initial_vesting_shares": {
        "amount": "12373786546",
        "nai": "@@000000037",
        "precision": 6
      },
      "new_account_name": "singapore"
    }
  }',
  '\x500973696e6761706f726505737465656db2ff88e102000000065645535453000000000000000000000656455354530000');

  PERFORM ASSERT_THIS_TEST('{"type":"system_warning_operation","value":{"message":"Changingmaximumblocksizefrom2097152to131072"}}',
    '\x522b4368616e67696e676d6178696d756d626c6f636b73697a6566726f6d32303937313532746f313331303732');
  PERFORM ASSERT_THIS_TEST('{"type":"producer_missed_operation","value":{"producer":"ladygaga"}}',
    '\x56086c61647967616761');
  PERFORM ASSERT_THIS_TEST('{"type":"failed_recurrent_transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"1","precision":3,"nai":"@@000000021"},"memo":"xx","consecutive_failures":12,"remaining_executions":12,"deleted":false}}',
    '\x5405616c69636503626f62010000000000000003535445454d00000278780c0c0000');

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
