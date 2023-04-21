DROP FUNCTION IF EXISTS hive.process_operation;
CREATE OR REPLACE FUNCTION hive.process_operation(
  operation hive.operation,
  operation_type smallint,
  proc TEXT
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS $BODY$
BEGIN
  -- Call user provided function, if it exists for given operation type
  BEGIN
    CASE operation_type OF
      WHEN 0 THEN EXECUTE format('CALL %I($1::hive.vote_operation)', proc) USING operation;
      WHEN 1 THEN EXECUTE format('CALL %I($1::hive.comment_operation)', proc) USING operation;
      WHEN 2 THEN EXECUTE format('CALL %I($1::hive.transfer_operation)', proc) USING operation;
      WHEN 3 THEN EXECUTE format('CALL %I($1::hive.transfer_to_vesting_operation)', proc) USING operation;
      WHEN 4 THEN EXECUTE format('CALL %I($1::hive.withdraw_vesting_operation)', proc) USING operation;
      WHEN 5 THEN EXECUTE format('CALL %I($1::hive.limit_order_create_operation)', proc) USING operation;
      WHEN 6 THEN EXECUTE format('CALL %I($1::hive.limit_order_cancel_operation)', proc) USING operation;
      WHEN 7 THEN EXECUTE format('CALL %I($1::hive.feed_publish_operation)', proc) USING operation;
      WHEN 8 THEN EXECUTE format('CALL %I($1::hive.convert_operation)', proc) USING operation;
      WHEN 9 THEN EXECUTE format('CALL %I($1::hive.account_create_operation)', proc) USING operation;
      WHEN 10 THEN EXECUTE format('CALL %I($1::hive.account_update_operation)', proc) USING operation;
      WHEN 11 THEN EXECUTE format('CALL %I($1::hive.witness_update_operation)', proc) USING operation;
      WHEN 12 THEN EXECUTE format('CALL %I($1::hive.account_witness_vote_operation)', proc) USING operation;
      WHEN 13 THEN EXECUTE format('CALL %I($1::hive.account_witness_proxy_operation)', proc) USING operation;
      WHEN 14 THEN EXECUTE format('CALL %I($1::hive.pow_operation)', proc) USING operation;
      WHEN 15 THEN EXECUTE format('CALL %I($1::hive.custom_operation)', proc) USING operation;
      WHEN 16 THEN EXECUTE format('CALL %I($1::hive.witness_block_approve_operation)', proc) USING operation;
      WHEN 17 THEN EXECUTE format('CALL %I($1::hive.delete_comment_operation)', proc) USING operation;
      WHEN 18 THEN EXECUTE format('CALL %I($1::hive.custom_json_operation)', proc) USING operation;
      WHEN 19 THEN EXECUTE format('CALL %I($1::hive.comment_options_operation)', proc) USING operation;
      WHEN 20 THEN EXECUTE format('CALL %I($1::hive.set_withdraw_vesting_route_operation)', proc) USING operation;
      WHEN 21 THEN EXECUTE format('CALL %I($1::hive.limit_order_create2_operation)', proc) USING operation;
      WHEN 22 THEN EXECUTE format('CALL %I($1::hive.claim_account_operation)', proc) USING operation;
      WHEN 23 THEN EXECUTE format('CALL %I($1::hive.create_claimed_account_operation)', proc) USING operation;
      WHEN 24 THEN EXECUTE format('CALL %I($1::hive.request_account_recovery_operation)', proc) USING operation;
      WHEN 25 THEN EXECUTE format('CALL %I($1::hive.recover_account_operation)', proc) USING operation;
      WHEN 26 THEN EXECUTE format('CALL %I($1::hive.change_recovery_account_operation)', proc) USING operation;
      WHEN 27 THEN EXECUTE format('CALL %I($1::hive.escrow_transfer_operation)', proc) USING operation;
      WHEN 28 THEN EXECUTE format('CALL %I($1::hive.escrow_dispute_operation)', proc) USING operation;
      WHEN 29 THEN EXECUTE format('CALL %I($1::hive.escrow_release_operation)', proc) USING operation;
      WHEN 30 THEN EXECUTE format('CALL %I($1::hive.pow2_operation)', proc) USING operation;
      WHEN 31 THEN EXECUTE format('CALL %I($1::hive.escrow_approve_operation)', proc) USING operation;
      WHEN 32 THEN EXECUTE format('CALL %I($1::hive.transfer_to_savings_operation)', proc) USING operation;
      WHEN 33 THEN EXECUTE format('CALL %I($1::hive.transfer_from_savings_operation)', proc) USING operation;
      WHEN 34 THEN EXECUTE format('CALL %I($1::hive.cancel_transfer_from_savings_operation)', proc) USING operation;
      WHEN 35 THEN EXECUTE format('CALL %I($1::hive.custom_binary_operation)', proc) USING operation;
      WHEN 36 THEN EXECUTE format('CALL %I($1::hive.decline_voting_rights_operation)', proc) USING operation;
      WHEN 37 THEN EXECUTE format('CALL %I($1::hive.reset_account_operation)', proc) USING operation;
      WHEN 38 THEN EXECUTE format('CALL %I($1::hive.set_reset_account_operation)', proc) USING operation;
      WHEN 39 THEN EXECUTE format('CALL %I($1::hive.claim_reward_balance_operation)', proc) USING operation;
      WHEN 40 THEN EXECUTE format('CALL %I($1::hive.delegate_vesting_shares_operation)', proc) USING operation;
      WHEN 41 THEN EXECUTE format('CALL %I($1::hive.account_create_with_delegation_operation)', proc) USING operation;
      WHEN 42 THEN EXECUTE format('CALL %I($1::hive.witness_set_properties_operation)', proc) USING operation;
      WHEN 43 THEN EXECUTE format('CALL %I($1::hive.account_update2_operation)', proc) USING operation;
      WHEN 44 THEN EXECUTE format('CALL %I($1::hive.create_proposal_operation)', proc) USING operation;
      WHEN 45 THEN EXECUTE format('CALL %I($1::hive.update_proposal_votes_operation)', proc) USING operation;
      WHEN 46 THEN EXECUTE format('CALL %I($1::hive.remove_proposal_operation)', proc) USING operation;
      WHEN 47 THEN EXECUTE format('CALL %I($1::hive.update_proposal_operation)', proc) USING operation;
      WHEN 48 THEN EXECUTE format('CALL %I($1::hive.collateralized_convert_operation)', proc) USING operation;
      WHEN 49 THEN EXECUTE format('CALL %I($1::hive.recurrent_transfer_operation)', proc) USING operation;
      WHEN 50 THEN EXECUTE format('CALL %I($1::hive.fill_convert_request_operation)', proc) USING operation;
      WHEN 51 THEN EXECUTE format('CALL %I($1::hive.author_reward_operation)', proc) USING operation;
      WHEN 52 THEN EXECUTE format('CALL %I($1::hive.curation_reward_operation)', proc) USING operation;
      WHEN 53 THEN EXECUTE format('CALL %I($1::hive.comment_reward_operation)', proc) USING operation;
      WHEN 54 THEN EXECUTE format('CALL %I($1::hive.liquidity_reward_operation)', proc) USING operation;
      WHEN 55 THEN EXECUTE format('CALL %I($1::hive.interest_operation)', proc) USING operation;
      WHEN 56 THEN EXECUTE format('CALL %I($1::hive.fill_vesting_withdraw_operation)', proc) USING operation;
      WHEN 57 THEN EXECUTE format('CALL %I($1::hive.fill_order_operation)', proc) USING operation;
      WHEN 58 THEN EXECUTE format('CALL %I($1::hive.shutdown_witness_operation)', proc) USING operation;
      WHEN 59 THEN EXECUTE format('CALL %I($1::hive.fill_transfer_from_savings_operation)', proc) USING operation;
      WHEN 60 THEN EXECUTE format('CALL %I($1::hive.hardfork_operation)', proc) USING operation;
      WHEN 61 THEN EXECUTE format('CALL %I($1::hive.comment_payout_update_operation)', proc) USING operation;
      WHEN 62 THEN EXECUTE format('CALL %I($1::hive.return_vesting_delegation_operation)', proc) USING operation;
      WHEN 63 THEN EXECUTE format('CALL %I($1::hive.comment_benefactor_reward_operation)', proc) USING operation;
      WHEN 64 THEN EXECUTE format('CALL %I($1::hive.producer_reward_operation)', proc) USING operation;
      WHEN 65 THEN EXECUTE format('CALL %I($1::hive.clear_null_account_balance_operation)', proc) USING operation;
      WHEN 66 THEN EXECUTE format('CALL %I($1::hive.proposal_pay_operation)', proc) USING operation;
      WHEN 67 THEN EXECUTE format('CALL %I($1::hive.dhf_funding_operation)', proc) USING operation;
      WHEN 68 THEN EXECUTE format('CALL %I($1::hive.hardfork_hive_operation)', proc) USING operation;
      WHEN 69 THEN EXECUTE format('CALL %I($1::hive.hardfork_hive_restore_operation)', proc) USING operation;
      WHEN 70 THEN EXECUTE format('CALL %I($1::hive.delayed_voting_operation)', proc) USING operation;
      WHEN 71 THEN EXECUTE format('CALL %I($1::hive.consolidate_treasury_balance_operation)', proc) USING operation;
      WHEN 72 THEN EXECUTE format('CALL %I($1::hive.effective_comment_vote_operation)', proc) USING operation;
      WHEN 73 THEN EXECUTE format('CALL %I($1::hive.ineffective_delete_comment_operation)', proc) USING operation;
      WHEN 74 THEN EXECUTE format('CALL %I($1::hive.dhf_conversion_operation)', proc) USING operation;
      WHEN 75 THEN EXECUTE format('CALL %I($1::hive.expired_account_notification_operation)', proc) USING operation;
      WHEN 76 THEN EXECUTE format('CALL %I($1::hive.changed_recovery_account_operation)', proc) USING operation;
      WHEN 77 THEN EXECUTE format('CALL %I($1::hive.transfer_to_vesting_completed_operation)', proc) USING operation;
      WHEN 78 THEN EXECUTE format('CALL %I($1::hive.pow_reward_operation)', proc) USING operation;
      WHEN 79 THEN EXECUTE format('CALL %I($1::hive.vesting_shares_split_operation)', proc) USING operation;
      WHEN 80 THEN EXECUTE format('CALL %I($1::hive.account_created_operation)', proc) USING operation;
      WHEN 81 THEN EXECUTE format('CALL %I($1::hive.fill_collateralized_convert_request_operation)', proc) USING operation;
      WHEN 82 THEN EXECUTE format('CALL %I($1::hive.system_warning_operation)', proc) USING operation;
      WHEN 83 THEN EXECUTE format('CALL %I($1::hive.fill_recurrent_transfer_operation)', proc) USING operation;
      WHEN 84 THEN EXECUTE format('CALL %I($1::hive.failed_recurrent_transfer_operation)', proc) USING operation;
      WHEN 85 THEN EXECUTE format('CALL %I($1::hive.limit_order_cancelled_operation)', proc) USING operation;
      WHEN 86 THEN EXECUTE format('CALL %I($1::hive.producer_missed_operation)', proc) USING operation;
      WHEN 87 THEN EXECUTE format('CALL %I($1::hive.proposal_fee_operation)', proc) USING operation;
      WHEN 88 THEN EXECUTE format('CALL %I($1::hive.collateralized_convert_immediate_conversion_operation)', proc) USING operation;
      WHEN 89 THEN EXECUTE format('CALL %I($1::hive.escrow_approved_operation)', proc) USING operation;
      WHEN 90 THEN EXECUTE format('CALL %I($1::hive.escrow_rejected_operation)', proc) USING operation;
      WHEN 91 THEN EXECUTE format('CALL %I($1::hive.proxy_cleared_operation)', proc) USING operation;
      WHEN 92 THEN EXECUTE format('CALL %I($1::hive.declined_voting_rights_operation)', proc) USING operation;
      ELSE RAISE 'Invalid operation type %', operation_type;
    END CASE;
  EXCEPTION
    WHEN undefined_function THEN RETURN;
  END;
END;
$BODY$;

DROP FUNCTION IF EXISTS hive.process_operation_c_impl;
CREATE OR REPLACE FUNCTION hive.process_operation_c_impl(
  operation hive.operation,
  proc TEXT
)
RETURNS void
LANGUAGE c
VOLATILE
AS 'MODULE_PATHNAME',
'process_operation';

DROP FUNCTION IF EXISTS hive.process_operation_c;
CREATE OR REPLACE FUNCTION hive.process_operation_c(
  operation hive.operation,
  proc TEXT
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS $BODY$
BEGIN
  BEGIN
    PERFORM hive.process_operation_c_impl(operation, proc);
  EXCEPTION
    WHEN undefined_function THEN RETURN;
  END;
END;
$BODY$;
