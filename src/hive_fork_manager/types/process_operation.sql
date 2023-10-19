-- Process an operation given in `op` record.  It should be any record type containing `body` and `op_type_id` columns of types `hive.operation` and `smallint` respectively.
-- Depending on the operation type in `op_type_id`, `op.body` will be cast to appropriate concrete operation type (e.g. vote_operation, custom_json_operation)
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
    WHEN 0 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.vote_operation)', namespace, proc) USING op;
    WHEN 1 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.comment_operation)', namespace, proc) USING op;
    WHEN 2 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.transfer_operation)', namespace, proc) USING op;
    WHEN 3 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.transfer_to_vesting_operation)', namespace, proc) USING op;
    WHEN 4 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.withdraw_vesting_operation)', namespace, proc) USING op;
    WHEN 5 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.limit_order_create_operation)', namespace, proc) USING op;
    WHEN 6 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.limit_order_cancel_operation)', namespace, proc) USING op;
    WHEN 7 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.feed_publish_operation)', namespace, proc) USING op;
    WHEN 8 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.convert_operation)', namespace, proc) USING op;
    WHEN 9 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.account_create_operation)', namespace, proc) USING op;
    WHEN 10 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.account_update_operation)', namespace, proc) USING op;
    WHEN 11 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.witness_update_operation)', namespace, proc) USING op;
    WHEN 12 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.account_witness_vote_operation)', namespace, proc) USING op;
    WHEN 13 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.account_witness_proxy_operation)', namespace, proc) USING op;
    WHEN 14 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.pow_operation)', namespace, proc) USING op;
    WHEN 15 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.custom_operation)', namespace, proc) USING op;
    WHEN 16 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.witness_block_approve_operation)', namespace, proc) USING op;
    WHEN 17 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.delete_comment_operation)', namespace, proc) USING op;
    WHEN 18 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.custom_json_operation)', namespace, proc) USING op;
    WHEN 19 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.comment_options_operation)', namespace, proc) USING op;
    WHEN 20 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.set_withdraw_vesting_route_operation)', namespace, proc) USING op;
    WHEN 21 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.limit_order_create2_operation)', namespace, proc) USING op;
    WHEN 22 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.claim_account_operation)', namespace, proc) USING op;
    WHEN 23 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.create_claimed_account_operation)', namespace, proc) USING op;
    WHEN 24 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.request_account_recovery_operation)', namespace, proc) USING op;
    WHEN 25 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.recover_account_operation)', namespace, proc) USING op;
    WHEN 26 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.change_recovery_account_operation)', namespace, proc) USING op;
    WHEN 27 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.escrow_transfer_operation)', namespace, proc) USING op;
    WHEN 28 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.escrow_dispute_operation)', namespace, proc) USING op;
    WHEN 29 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.escrow_release_operation)', namespace, proc) USING op;
    WHEN 30 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.pow2_operation)', namespace, proc) USING op;
    WHEN 31 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.escrow_approve_operation)', namespace, proc) USING op;
    WHEN 32 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.transfer_to_savings_operation)', namespace, proc) USING op;
    WHEN 33 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.transfer_from_savings_operation)', namespace, proc) USING op;
    WHEN 34 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.cancel_transfer_from_savings_operation)', namespace, proc) USING op;
    WHEN 35 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.custom_binary_operation)', namespace, proc) USING op;
    WHEN 36 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.decline_voting_rights_operation)', namespace, proc) USING op;
    WHEN 37 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.reset_account_operation)', namespace, proc) USING op;
    WHEN 38 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.set_reset_account_operation)', namespace, proc) USING op;
    WHEN 39 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.claim_reward_balance_operation)', namespace, proc) USING op;
    WHEN 40 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.delegate_vesting_shares_operation)', namespace, proc) USING op;
    WHEN 41 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.account_create_with_delegation_operation)', namespace, proc) USING op;
    WHEN 42 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.witness_set_properties_operation)', namespace, proc) USING op;
    WHEN 43 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.account_update2_operation)', namespace, proc) USING op;
    WHEN 44 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.create_proposal_operation)', namespace, proc) USING op;
    WHEN 45 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.update_proposal_votes_operation)', namespace, proc) USING op;
    WHEN 46 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.remove_proposal_operation)', namespace, proc) USING op;
    WHEN 47 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.update_proposal_operation)', namespace, proc) USING op;
    WHEN 48 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.collateralized_convert_operation)', namespace, proc) USING op;
    WHEN 49 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.recurrent_transfer_operation)', namespace, proc) USING op;
    WHEN 50 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.fill_convert_request_operation)', namespace, proc) USING op;
    WHEN 51 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.author_reward_operation)', namespace, proc) USING op;
    WHEN 52 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.curation_reward_operation)', namespace, proc) USING op;
    WHEN 53 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.comment_reward_operation)', namespace, proc) USING op;
    WHEN 54 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.liquidity_reward_operation)', namespace, proc) USING op;
    WHEN 55 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.interest_operation)', namespace, proc) USING op;
    WHEN 56 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.fill_vesting_withdraw_operation)', namespace, proc) USING op;
    WHEN 57 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.fill_order_operation)', namespace, proc) USING op;
    WHEN 58 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.shutdown_witness_operation)', namespace, proc) USING op;
    WHEN 59 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.fill_transfer_from_savings_operation)', namespace, proc) USING op;
    WHEN 60 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.hardfork_operation)', namespace, proc) USING op;
    WHEN 61 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.comment_payout_update_operation)', namespace, proc) USING op;
    WHEN 62 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.return_vesting_delegation_operation)', namespace, proc) USING op;
    WHEN 63 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.comment_benefactor_reward_operation)', namespace, proc) USING op;
    WHEN 64 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.producer_reward_operation)', namespace, proc) USING op;
    WHEN 65 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.clear_null_account_balance_operation)', namespace, proc) USING op;
    WHEN 66 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.proposal_pay_operation)', namespace, proc) USING op;
    WHEN 67 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.dhf_funding_operation)', namespace, proc) USING op;
    WHEN 68 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.hardfork_hive_operation)', namespace, proc) USING op;
    WHEN 69 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.hardfork_hive_restore_operation)', namespace, proc) USING op;
    WHEN 70 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.delayed_voting_operation)', namespace, proc) USING op;
    WHEN 71 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.consolidate_treasury_balance_operation)', namespace, proc) USING op;
    WHEN 72 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.effective_comment_vote_operation)', namespace, proc) USING op;
    WHEN 73 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.ineffective_delete_comment_operation)', namespace, proc) USING op;
    WHEN 74 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.dhf_conversion_operation)', namespace, proc) USING op;
    WHEN 75 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.expired_account_notification_operation)', namespace, proc) USING op;
    WHEN 76 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.changed_recovery_account_operation)', namespace, proc) USING op;
    WHEN 77 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.transfer_to_vesting_completed_operation)', namespace, proc) USING op;
    WHEN 78 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.pow_reward_operation)', namespace, proc) USING op;
    WHEN 79 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.vesting_shares_split_operation)', namespace, proc) USING op;
    WHEN 80 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.account_created_operation)', namespace, proc) USING op;
    WHEN 81 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.fill_collateralized_convert_request_operation)', namespace, proc) USING op;
    WHEN 82 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.system_warning_operation)', namespace, proc) USING op;
    WHEN 83 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.fill_recurrent_transfer_operation)', namespace, proc) USING op;
    WHEN 84 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.failed_recurrent_transfer_operation)', namespace, proc) USING op;
    WHEN 85 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.limit_order_cancelled_operation)', namespace, proc) USING op;
    WHEN 86 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.producer_missed_operation)', namespace, proc) USING op;
    WHEN 87 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.proposal_fee_operation)', namespace, proc) USING op;
    WHEN 88 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.collateralized_convert_immediate_conversion_operation)', namespace, proc) USING op;
    WHEN 89 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.escrow_approved_operation)', namespace, proc) USING op;
    WHEN 90 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.escrow_rejected_operation)', namespace, proc) USING op;
    WHEN 91 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.proxy_cleared_operation)', namespace, proc) USING op;
    WHEN 92 THEN EXECUTE format('SELECT %I.%I($1, $1.body_binary::hive.declined_voting_rights_operation)', namespace, proc) USING op;
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
