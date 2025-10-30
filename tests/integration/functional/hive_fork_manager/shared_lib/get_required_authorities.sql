CREATE OR REPLACE FUNCTION assert_get_required_authorities(op_text TEXT, expected TEXT, err_msg TEXT)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  _result_text hive.get_required_authorities_return_type[];
  _result_jsonb hive.get_required_authorities_return_type[];
  _result_op hive.get_required_authorities_return_type[];
  _expected_typed hive.get_required_authorities_return_type[];
BEGIN
  SELECT COALESCE(
    ARRAY_AGG(f),
    '{}'::hive.get_required_authorities_return_type[]
  )
  INTO _result_op
  FROM hive.get_required_authorities(op_text :: jsonb :: hafd.operation) AS f;

  SELECT COALESCE(
    ARRAY_AGG(f),
    '{}'::hive.get_required_authorities_return_type[]
  )
  INTO _result_text
  FROM hive.get_required_authorities(op_text) AS f;

  SELECT COALESCE(
    ARRAY_AGG(f),
    '{}'::hive.get_required_authorities_return_type[]
  )
  INTO _result_jsonb
  FROM hive.get_required_authorities(op_text :: jsonb) AS f;

  _expected_typed := (expected)::hive.get_required_authorities_return_type[];
  ASSERT _expected_typed = _result_op, err_msg || ' (hafd.operation overload)';
  ASSERT _expected_typed = _result_text, err_msg || ' (text overload)';
  ASSERT _expected_typed = _result_jsonb, err_msg || ' (jsonb overload)';
END;
$$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN

PERFORM assert_get_required_authorities(
  '{"type":"transfer_operation","value":{"from":"alice","to":"bob","amount":{"amount":"1000","precision":3,"nai":"@@000000021"},"memo":""}}',
  '{"(alice,active)"}',
  'Broken get_required_authorities result for transfer_operation'
);

PERFORM assert_get_required_authorities(
  '{"type":"vote_operation","value":{"voter":"alice","author":"bob","permlink":"post","weight":1000}}',
  '{}',
  'Broken get_required_authorities result for posting-only operation (should be empty)'
);

  PERFORM assert_get_required_authorities(
    '{"type":"create_proposal_operation","value":{"creator":"carol","receiver":"dave","start_date":"2020-01-01T00:00:00","end_date":"2020-01-10T00:00:00","daily_pay":{"amount":"5000","precision":3,"nai":"@@000000013"},"subject":"test proposal","permlink":"test-permlink","extensions":[]}}',
    '{"(carol,active)"}',
    'Broken get_required_authorities result for create_proposal_operation'
  );

  PERFORM assert_get_required_authorities(
    '{"type":"update_proposal_operation","value":{"proposal_id":1,"creator":"carol","daily_pay":{"amount":"4000","precision":3,"nai":"@@000000013"},"subject":"updated proposal","permlink":"test-permlink","extensions":[]}}',
    '{"(carol,active)"}',
    'Broken get_required_authorities result for update_proposal_operation'
  );

  PERFORM assert_get_required_authorities(
    '{"type":"update_proposal_votes_operation","value":{"voter":"erin","proposal_ids":[1,2,3],"approve":true,"extensions":[]}}',
    '{"(erin,active)"}',
    'Broken get_required_authorities result for update_proposal_votes_operation'
  );

  PERFORM assert_get_required_authorities(
    '{"type":"remove_proposal_operation","value":{"proposal_owner":"frank","proposal_ids":[10,11],"extensions":[]}}',
    '{"(frank,active)"}',
    'Broken get_required_authorities result for remove_proposal_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"account_create_operation",
      "value":{
        "fee":{"amount":"1000","precision":3,"nai":"@@000000021"},
        "creator":"george",
        "new_account_name":"newacc1",
        "owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "memo_key":"STM1111111111111111111111111111111114T1Anm",
        "json_metadata":"{}"
      }
    }',
    '{"(george,active)"}',
    'Broken get_required_authorities result for account_create_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"account_create_with_delegation_operation",
      "value":{
        "fee":{"amount":"1000","precision":3,"nai":"@@000000021"},
        "delegation":{"amount":"1000000","precision":6,"nai":"@@000000037"},
        "creator":"henry",
        "new_account_name":"newacc2",
        "owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "memo_key":"STM1111111111111111111111111111111114T1Anm",
        "json_metadata":"{}",
        "extensions":[]
      }
    }',
    '{"(henry,active)"}',
    'Broken get_required_authorities result for account_create_with_delegation_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"account_update_operation",
      "value":{
        "account":"ingrid",
        "memo_key":"STM1111111111111111111111111111111114T1Anm",
        "json_metadata":"{}"
      }
    }',
    '{"(ingrid,active)"}',
    'Broken get_required_authorities result for account_update_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"account_update2_operation",
      "value":{
        "account":"jane",
        "json_metadata":"{}",
        "posting_json_metadata":""
      }
    }',
    '{"(jane,active)"}',
    'Broken get_required_authorities result for account_update2_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"claim_account_operation",
      "value":{
        "creator":"kate",
        "fee":{"amount":"0","precision":3,"nai":"@@000000021"},
        "extensions":[]
      }
    }',
    '{"(kate,active)"}',
    'Broken get_required_authorities result for claim_account_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"create_claimed_account_operation",
      "value":{
        "creator":"luke",
        "new_account_name":"newacc3",
        "owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]},
        "memo_key":"STM1111111111111111111111111111111114T1Anm",
        "json_metadata":"{}",
        "extensions":[]
      }
    }',
    '{"(luke,active)"}',
    'Broken get_required_authorities result for create_claimed_account_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"escrow_transfer_operation",
      "value":{
        "from":"mike",
        "to":"userb",
        "agent":"agent1",
        "escrow_id":1,
        "hbd_amount":{"amount":"10","precision":3,"nai":"@@000000013"},
        "hive_amount":{"amount":"0","precision":3,"nai":"@@000000021"},
        "fee":{"amount":"1","precision":3,"nai":"@@000000021"},
        "json_meta":"{}",
        "ratification_deadline":"2020-01-02T00:00:00",
        "escrow_expiration":"2020-01-10T00:00:00"
      }
    }',
    '{"(mike,active)"}',
    'Broken get_required_authorities result for escrow_transfer_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"escrow_approve_operation",
      "value":{
        "from":"mike",
        "to":"userb",
        "agent":"agent1",
        "who":"nina",
        "escrow_id":1,
        "approve":true
      }
    }',
    '{"(nina,active)"}',
    'Broken get_required_authorities result for escrow_approve_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"escrow_dispute_operation",
      "value":{
        "from":"mike",
        "to":"userb",
        "agent":"agent1",
        "who":"olga",
        "escrow_id":1
      }
    }',
    '{"(olga,active)"}',
    'Broken get_required_authorities result for escrow_dispute_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"escrow_release_operation",
      "value":{
        "from":"mike",
        "to":"userb",
        "agent":"agent1",
        "who":"paul",
        "receiver":"userb",
        "escrow_id":1,
        "hbd_amount":{"amount":"0","precision":3,"nai":"@@000000013"},
        "hive_amount":{"amount":"1","precision":3,"nai":"@@000000021"}
      }
    }',
    '{"(paul,active)"}',
    'Broken get_required_authorities result for escrow_release_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"transfer_to_vesting_operation",
      "value":{
        "from":"quinn",
        "to":"",
        "amount":{"amount":"1000","precision":3,"nai":"@@000000021"}
      }
    }',
    '{"(quinn,active)"}',
    'Broken get_required_authorities result for transfer_to_vesting_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"withdraw_vesting_operation",
      "value":{
        "account":"rita",
        "vesting_shares":{"amount":"1000000","precision":6,"nai":"@@000000037"}
      }
    }',
    '{"(rita,active)"}',
    'Broken get_required_authorities result for withdraw_vesting_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"set_withdraw_vesting_route_operation",
      "value":{
        "from_account":"sam",
        "to_account":"userc",
        "percent":1000,
        "auto_vest":false
      }
    }',
    '{"(sam,active)"}',
    'Broken get_required_authorities result for set_withdraw_vesting_route_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"witness_update_operation",
      "value":{
        "owner":"tom",
        "url":"http://url.html",
        "block_signing_key":"STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW",
        "props":{
          "account_creation_fee":{"amount":"10000","precision":3,"nai":"@@000000021"},
          "maximum_block_size":131072,
          "hbd_interest_rate":1000
        },
        "fee":{"amount":"0","precision":3,"nai":"@@000000021"}
      }
    }',
    '{"(tom,active)"}',
    'Broken get_required_authorities result for witness_update_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"account_witness_vote_operation",
      "value":{
        "account":"uma",
        "witness":"initminer",
        "approve":true
      }
    }',
    '{"(uma,active)"}',
    'Broken get_required_authorities result for account_witness_vote_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"account_witness_proxy_operation",
      "value":{
        "account":"victor",
        "proxy":"alice"
      }
    }',
    '{"(victor,active)"}',
    'Broken get_required_authorities result for account_witness_proxy_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"custom_operation",
      "value":{
        "required_auths":["walt"],
        "id":777,
        "data":"0a"
      }
    }',
    '{"(walt,active)"}',
    'Broken get_required_authorities result for custom_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"custom_json_operation",
      "value":{
        "required_auths":["xena"],
        "required_posting_auths":[],
        "id":"follow",
        "json":"{}"
      }
    }',
    '{"(xena,active)"}',
    'Broken get_required_authorities result for custom_json_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"custom_binary_operation",
      "value":{
        "required_owner_auths":[],
        "required_active_auths":["yuri"],
        "required_posting_auths":[],
        "required_auths":[],
        "id":"binid",
        "data":""
      }
    }',
    '{"(yuri,active)"}',
    'Broken get_required_authorities result for custom_binary_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"feed_publish_operation",
      "value":{
        "publisher":"initminer",
        "exchange_rate":{
          "base":{"amount":"1","precision":3,"nai":"@@000000013"},
          "quote":{"amount":"1","precision":3,"nai":"@@000000021"}
        }
      }
    }',
    '{"(initminer,active)"}',
    'Broken get_required_authorities result for feed_publish_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"convert_operation",
      "value":{
        "owner":"adam",
        "requestid":1,
        "amount":{"amount":"127144","precision":3,"nai":"@@000000013"}
      }
    }',
    '{"(adam,active)"}',
    'Broken get_required_authorities result for convert_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"collateralized_convert_operation",
      "value":{
        "owner":"beth",
        "requestid":1,
        "amount":{"amount":"1000","precision":3,"nai":"@@000000021"}
      }
    }',
    '{"(beth,active)"}',
    'Broken get_required_authorities result for collateralized_convert_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"limit_order_create_operation",
      "value":{
        "owner":"carl",
        "orderid":100,
        "amount_to_sell":{"amount":"1000","precision":3,"nai":"@@000000021"},
        "min_to_receive":{"amount":"1000","precision":3,"nai":"@@000000013"},
        "fill_or_kill":false,
        "expiration":"2023-01-02T11:43:07"
      }
    }',
    '{"(carl,active)"}',
    'Broken get_required_authorities result for limit_order_create_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"limit_order_create2_operation",
      "value":{
        "owner":"dina",
        "orderid":101,
        "amount_to_sell":{"amount":"1000","precision":3,"nai":"@@000000021"},
        "fill_or_kill":false,
        "exchange_rate":{
          "base":{"amount":"1","precision":3,"nai":"@@000000013"},
          "quote":{"amount":"1","precision":3,"nai":"@@000000021"}
        },
        "expiration":"2023-01-02T11:43:07"
      }
    }',
    '{"(dina,active)"}',
    'Broken get_required_authorities result for limit_order_create2_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"limit_order_cancel_operation",
      "value":{
        "owner":"edgar",
        "orderid":1
      }
    }',
    '{"(edgar,active)"}',
    'Broken get_required_authorities result for limit_order_cancel_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
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
    '{}',
    'Broken get_required_authorities result for pow_operation (should be empty)'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type": "pow2_operation",
      "value": {
        "props": {
          "account_creation_fee": {"amount": "1","nai": "@@000000021","precision": 3},
          "hbd_interest_rate": 1000,
          "maximum_block_size": 131072
        },
        "work": {"type": "pow2","value": {"input": {"nonce": "2363830237862599931","prev_block": "003ead0c90b0cd80e9145805d303957015c50ef1","worker_account": "thedao"},"pow_summary": 3878270667}}
      }
    }',
    '{"(thedao,active)"}',
    'Broken get_required_authorities result for pow2_operation (should be empty)'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"request_account_recovery_operation",
      "value":{
        "recovery_account":"initminer",
        "account_to_recover":"alice",
        "new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5P8syqoj7itoDjbtDvCMCb5W3BNJtUjws9v7TDNZKqBLmp3pQW",1]]},
        "extensions":[]
      }
    }',
    '{"(initminer,active)"}',
    'Broken get_required_authorities result for request_account_recovery_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"reset_account_operation",
      "value":{
        "reset_account":"resetter",
        "account_to_reset":"bob",
        "new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM1111111111111111111111111111111114T1Anm",1]]}
      }
    }',
    '{"(resetter,active)"}',
    'Broken get_required_authorities result for reset_account_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"transfer_to_savings_operation",
      "value":{
        "from":"u1",
        "to":"u1savings",
        "amount":{"amount":"100000","precision":3,"nai":"@@000000021"},
        "memo":"memo"
      }
    }',
    '{"(u1,active)"}',
    'Broken get_required_authorities result for transfer_to_savings_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"transfer_from_savings_operation",
      "value":{
        "from":"u2",
        "request_id":1000,
        "to":"u2main",
        "amount":{"amount":"1000","precision":3,"nai":"@@000000021"},
        "memo":"memo"
      }
    }',
    '{"(u2,active)"}',
    'Broken get_required_authorities result for transfer_from_savings_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"cancel_transfer_from_savings_operation",
      "value":{
        "from":"u3",
        "request_id":1
      }
    }',
    '{"(u3,active)"}',
    'Broken get_required_authorities result for cancel_transfer_from_savings_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"delegate_vesting_shares_operation",
      "value":{
        "delegator":"del",
        "delegatee":"rec",
        "vesting_shares":{"amount":"1000000","precision":6,"nai":"@@000000037"}
      }
    }',
    '{"(del,active)"}',
    'Broken get_required_authorities result for delegate_vesting_shares_operation'
  );

  PERFORM assert_get_required_authorities(
    '{
      "type":"recurrent_transfer_operation",
      "value":{
        "from":"rfrom",
        "to":"rto",
        "amount":{"amount":"5000","precision":3,"nai":"@@000000021"},
        "memo":"memo",
        "recurrence":720,
        "executions":12,
        "extensions":[]
      }
    }',
    '{"(rfrom,active)"}',
    'Broken get_required_authorities result for recurrent_transfer_operation'
  );
END;
$BODY$
;
