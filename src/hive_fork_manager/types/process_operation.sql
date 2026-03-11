-- Process an operation given in `op` record.  It should be any record type containing `body_value` (jsonb) and `op_type_id` (smallint) columns.
-- Depending on the operation type in `op_type_id`, `op.body_value` will be deserialized via jsonb_populate_record to the appropriate concrete operation type (e.g. vote_operation, custom_json_operation)
-- and passed to user provided function given by `namespace` and `proc`.
-- Provided function overload must exist for given operation type. Otherwise an exception is raised.
DROP FUNCTION IF EXISTS hive.process_operation;
CREATE OR REPLACE FUNCTION hive.process_operation(
  op RECORD,
  namespace TEXT,
  proc TEXT
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SET plan_cache_mode=force_generic_plan
SET jit=OFF
AS $BODY$
BEGIN
  CASE op.op_type_id OF
    WHEN 0 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.vote_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 1 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.comment_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 2 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.transfer_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 3 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.transfer_to_vesting_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 4 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.withdraw_vesting_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 5 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.limit_order_create_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 6 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.limit_order_cancel_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 7 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.feed_publish_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 8 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.convert_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 9 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.account_create_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 10 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.account_update_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 11 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.witness_update_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 12 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.account_witness_vote_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 13 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.account_witness_proxy_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 14 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.pow_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 15 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.custom_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 16 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.witness_block_approve_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 17 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.delete_comment_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 18 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.custom_json_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 19 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.comment_options_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 20 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.set_withdraw_vesting_route_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 21 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.limit_order_create2_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 22 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.claim_account_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 23 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.create_claimed_account_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 24 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.request_account_recovery_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 25 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.recover_account_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 26 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.change_recovery_account_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 27 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.escrow_transfer_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 28 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.escrow_dispute_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 29 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.escrow_release_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 30 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.pow2_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 31 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.escrow_approve_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 32 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.transfer_to_savings_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 33 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.transfer_from_savings_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 34 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.cancel_transfer_from_savings_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 35 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.custom_binary_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 36 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.decline_voting_rights_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 37 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.reset_account_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 38 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.set_reset_account_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 39 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.claim_reward_balance_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 40 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.delegate_vesting_shares_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 41 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.account_create_with_delegation_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 42 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.witness_set_properties_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 43 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.account_update2_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 44 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.create_proposal_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 45 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.update_proposal_votes_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 46 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.remove_proposal_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 47 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.update_proposal_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 48 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.collateralized_convert_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 49 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.recurrent_transfer_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 50 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.fill_convert_request_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 51 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.author_reward_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 52 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.curation_reward_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 53 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.comment_reward_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 54 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.liquidity_reward_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 55 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.interest_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 56 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.fill_vesting_withdraw_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 57 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.fill_order_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 58 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.shutdown_witness_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 59 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.fill_transfer_from_savings_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 60 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.hardfork_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 61 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.comment_payout_update_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 62 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.return_vesting_delegation_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 63 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.comment_benefactor_reward_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 64 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.producer_reward_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 65 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.clear_null_account_balance_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 66 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.proposal_pay_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 67 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.dhf_funding_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 68 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.hardfork_hive_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 69 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.hardfork_hive_restore_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 70 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.delayed_voting_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 71 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.consolidate_treasury_balance_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 72 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.effective_comment_vote_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 73 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.ineffective_delete_comment_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 74 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.dhf_conversion_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 75 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.expired_account_notification_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 76 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.changed_recovery_account_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 77 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.transfer_to_vesting_completed_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 78 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.pow_reward_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 79 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.vesting_shares_split_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 80 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.account_created_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 81 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.fill_collateralized_convert_request_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 82 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.system_warning_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 83 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.fill_recurrent_transfer_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 84 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.failed_recurrent_transfer_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 85 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.limit_order_cancelled_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 86 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.producer_missed_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 87 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.proposal_fee_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 88 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.collateralized_convert_immediate_conversion_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 89 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.escrow_approved_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 90 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.escrow_rejected_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 91 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.proxy_cleared_operation, $1.body_value))', namespace, proc) USING op;
    WHEN 92 THEN EXECUTE format('SELECT %I.%I($1, jsonb_populate_record(NULL::hive.declined_voting_rights_operation, $1.body_value))', namespace, proc) USING op;
    ELSE RAISE 'Invalid operation type %', op.op_type_id;
  END CASE;
END;
$BODY$;

-- Same as process_operation, but wrapped in an exception block.
-- In case provided function overload does not exist for given operation type, no processing is done and functions simply returns without an error.
-- Any other exception is still reraised.
-- Prefer process_operation, as it's more performant.
DROP FUNCTION IF EXISTS hive.process_operation_noexcept;
CREATE OR REPLACE FUNCTION hive.process_operation_noexcept(
  op RECORD,
  namespace TEXT,
  proc TEXT
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SET plan_cache_mode=force_generic_plan
SET jit=OFF
AS $BODY$
BEGIN
  BEGIN
    SELECT hive.process_operation(op, namespace, proc);
  EXCEPTION
    WHEN undefined_function THEN RETURN;
    WHEN others THEN RAISE;
  END;
END;
$BODY$;
