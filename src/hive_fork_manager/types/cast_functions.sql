CREATE OR REPLACE FUNCTION hive._operation_to_comment_operation(
  hive.operation
) RETURNS hive.comment_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_comment_options_operation(
  hive.operation
) RETURNS hive.comment_options_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_options_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_vote_operation(
  hive.operation
) RETURNS hive.vote_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_vote_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_witness_set_properties_operation(
  hive.operation
) RETURNS hive.witness_set_properties_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_witness_set_properties_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_account_create_operation(
  hive.operation
) RETURNS hive.account_create_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_create_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_account_create_with_delegation_operation(
  hive.operation
) RETURNS hive.account_create_with_delegation_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_create_with_delegation_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_account_update2_operation(
  hive.operation
) RETURNS hive.account_update2_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_update2_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_account_update_operation(
  hive.operation
) RETURNS hive.account_update_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_update_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_account_witness_proxy_operation(
  hive.operation
) RETURNS hive.account_witness_proxy_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_witness_proxy_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_account_witness_vote_operation(
  hive.operation
) RETURNS hive.account_witness_vote_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_witness_vote_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_cancel_transfer_from_savings_operation(
  hive.operation
) RETURNS hive.cancel_transfer_from_savings_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_cancel_transfer_from_savings_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_change_recovery_account_operation(
  hive.operation
) RETURNS hive.change_recovery_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_change_recovery_account_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_claim_account_operation(
  hive.operation
) RETURNS hive.claim_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_claim_account_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_claim_reward_balance_operation(
  hive.operation
) RETURNS hive.claim_reward_balance_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_claim_reward_balance_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_collateralized_convert_operation(
  hive.operation
) RETURNS hive.collateralized_convert_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_collateralized_convert_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_convert_operation(
  hive.operation
) RETURNS hive.convert_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_convert_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_create_claimed_account_operation(
  hive.operation
) RETURNS hive.create_claimed_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_create_claimed_account_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_custom_binary_operation(
  hive.operation
) RETURNS hive.custom_binary_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_custom_binary_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_custom_json_operation(
  hive.operation
) RETURNS hive.custom_json_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_custom_json_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_custom_operation(
  hive.operation
) RETURNS hive.custom_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_custom_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_decline_voting_rights_operation(
  hive.operation
) RETURNS hive.decline_voting_rights_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_decline_voting_rights_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_delegate_vesting_shares_operation(
  hive.operation
) RETURNS hive.delegate_vesting_shares_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_delegate_vesting_shares_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_delete_comment_operation(
  hive.operation
) RETURNS hive.delete_comment_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_delete_comment_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_approve_operation(
  hive.operation
) RETURNS hive.escrow_approve_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_approve_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_dispute_operation(
  hive.operation
) RETURNS hive.escrow_dispute_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_dispute_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_release_operation(
  hive.operation
) RETURNS hive.escrow_release_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_release_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_transfer_operation(
  hive.operation
) RETURNS hive.escrow_transfer_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_transfer_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_feed_publish_operation(
  hive.operation
) RETURNS hive.feed_publish_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_feed_publish_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_limit_order_cancel_operation(
  hive.operation
) RETURNS hive.limit_order_cancel_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_limit_order_cancel_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_limit_order_create2_operation(
  hive.operation
) RETURNS hive.limit_order_create2_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_limit_order_create2_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_limit_order_create_operation(
  hive.operation
) RETURNS hive.limit_order_create_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_limit_order_create_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_pow2_operation(
  hive.operation
) RETURNS hive.pow2_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_pow2_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_pow_operation(
  hive.operation
) RETURNS hive.pow_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_pow_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_recover_account_operation(
  hive.operation
) RETURNS hive.recover_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_recover_account_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_recurrent_transfer_operation(
  hive.operation
) RETURNS hive.recurrent_transfer_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_recurrent_transfer_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_request_account_recovery_operation(
  hive.operation
) RETURNS hive.request_account_recovery_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_request_account_recovery_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_reset_account_operation(
  hive.operation
) RETURNS hive.reset_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_reset_account_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_set_reset_account_operation(
  hive.operation
) RETURNS hive.set_reset_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_set_reset_account_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_set_withdraw_vesting_route_operation(
  hive.operation
) RETURNS hive.set_withdraw_vesting_route_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_set_withdraw_vesting_route_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_transfer_from_savings_operation(
  hive.operation
) RETURNS hive.transfer_from_savings_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_transfer_from_savings_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_transfer_operation(
  hive.operation
) RETURNS hive.transfer_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_transfer_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_transfer_to_savings_operation(
  hive.operation
) RETURNS hive.transfer_to_savings_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_transfer_to_savings_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_transfer_to_vesting_operation(
  hive.operation
) RETURNS hive.transfer_to_vesting_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_transfer_to_vesting_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_withdraw_vesting_operation(
  hive.operation
) RETURNS hive.withdraw_vesting_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_withdraw_vesting_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_witness_update_operation(
  hive.operation
) RETURNS hive.witness_update_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_witness_update_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_create_proposal_operation(
  hive.operation
) RETURNS hive.create_proposal_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_create_proposal_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_proposal_pay_operation(
  hive.operation
) RETURNS hive.proposal_pay_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_proposal_pay_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_remove_proposal_operation(
  hive.operation
) RETURNS hive.remove_proposal_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_remove_proposal_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_update_proposal_operation(
  hive.operation
) RETURNS hive.update_proposal_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_update_proposal_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_update_proposal_votes_operation(
  hive.operation
) RETURNS hive.update_proposal_votes_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_update_proposal_votes_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_account_created_operation(
  hive.operation
) RETURNS hive.account_created_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_created_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_author_reward_operation(
  hive.operation
) RETURNS hive.author_reward_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_author_reward_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_changed_recovery_account_operation(
  hive.operation
) RETURNS hive.changed_recovery_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_changed_recovery_account_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_clear_null_account_balance_operation(
  hive.operation
) RETURNS hive.clear_null_account_balance_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_clear_null_account_balance_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_comment_benefactor_reward_operation(
  hive.operation
) RETURNS hive.comment_benefactor_reward_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_benefactor_reward_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_comment_payout_update_operation(
  hive.operation
) RETURNS hive.comment_payout_update_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_payout_update_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_comment_reward_operation(
  hive.operation
) RETURNS hive.comment_reward_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_reward_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_consolidate_treasury_balance_operation(
  hive.operation
) RETURNS hive.consolidate_treasury_balance_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_consolidate_treasury_balance_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_curation_reward_operation(
  hive.operation
) RETURNS hive.curation_reward_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_curation_reward_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_delayed_voting_operation(
  hive.operation
) RETURNS hive.delayed_voting_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_delayed_voting_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_effective_comment_vote_operation(
  hive.operation
) RETURNS hive.effective_comment_vote_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_effective_comment_vote_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_expired_account_notification_operation(
  hive.operation
) RETURNS hive.expired_account_notification_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_expired_account_notification_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_failed_recurrent_transfer_operation(
  hive.operation
) RETURNS hive.failed_recurrent_transfer_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_failed_recurrent_transfer_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_fill_collateralized_convert_request_operation(
  hive.operation
) RETURNS hive.fill_collateralized_convert_request_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_fill_collateralized_convert_request_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_fill_convert_request_operation(
  hive.operation
) RETURNS hive.fill_convert_request_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_fill_convert_request_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_fill_order_operation(
  hive.operation
) RETURNS hive.fill_order_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_fill_order_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_fill_recurrent_transfer_operation(
  hive.operation
) RETURNS hive.fill_recurrent_transfer_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_fill_recurrent_transfer_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_fill_transfer_from_savings_operation(
  hive.operation
) RETURNS hive.fill_transfer_from_savings_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_fill_transfer_from_savings_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_fill_vesting_withdraw_operation(
  hive.operation
) RETURNS hive.fill_vesting_withdraw_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_fill_vesting_withdraw_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_hardfork_hive_operation(
  hive.operation
) RETURNS hive.hardfork_hive_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_hardfork_hive_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_hardfork_hive_restore_operation(
  hive.operation
) RETURNS hive.hardfork_hive_restore_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_hardfork_hive_restore_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_hardfork_operation(
  hive.operation
) RETURNS hive.hardfork_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_hardfork_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_ineffective_delete_comment_operation(
  hive.operation
) RETURNS hive.ineffective_delete_comment_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_ineffective_delete_comment_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_interest_operation(
  hive.operation
) RETURNS hive.interest_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_interest_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_limit_order_cancelled_operation(
  hive.operation
) RETURNS hive.limit_order_cancelled_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_limit_order_cancelled_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_liquidity_reward_operation(
  hive.operation
) RETURNS hive.liquidity_reward_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_liquidity_reward_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_pow_reward_operation(
  hive.operation
) RETURNS hive.pow_reward_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_pow_reward_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_producer_reward_operation(
  hive.operation
) RETURNS hive.producer_reward_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_producer_reward_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_return_vesting_delegation_operation(
  hive.operation
) RETURNS hive.return_vesting_delegation_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_return_vesting_delegation_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_shutdown_witness_operation(
  hive.operation
) RETURNS hive.shutdown_witness_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_shutdown_witness_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_system_warning_operation(
  hive.operation
) RETURNS hive.system_warning_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_system_warning_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_transfer_to_vesting_completed_operation(
  hive.operation
) RETURNS hive.transfer_to_vesting_completed_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_transfer_to_vesting_completed_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_vesting_shares_split_operation(
  hive.operation
) RETURNS hive.vesting_shares_split_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_vesting_shares_split_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_witness_block_approve_operation(
  hive.operation
) RETURNS hive.witness_block_approve_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_witness_block_approve_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_dhf_funding_operation(
  hive.operation
) RETURNS hive.dhf_funding_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_dhf_funding_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_dhf_conversion_operation(
  hive.operation
) RETURNS hive.dhf_conversion_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_dhf_conversion_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_producer_missed_operation(
  hive.operation
) RETURNS hive.producer_missed_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_producer_missed_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_proposal_fee_operation(
  hive.operation
) RETURNS hive.proposal_fee_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_proposal_fee_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_collateralized_convert_immediate_conversion_operation(
  hive.operation
) RETURNS hive.collateralized_convert_immediate_conversion_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_collateralized_convert_immediate_conversion_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_approved_operation(
  hive.operation
) RETURNS hive.escrow_approved_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_approved_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_rejected_operation(
  hive.operation
) RETURNS hive.escrow_rejected_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_rejected_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_proxy_cleared_operation(
  hive.operation
) RETURNS hive.proxy_cleared_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_proxy_cleared_operation';

CREATE OR REPLACE FUNCTION hive._operation_to_declined_voting_rights_operation(
  hive.operation
) RETURNS hive.declined_voting_rights_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_declined_voting_rights_operation';

