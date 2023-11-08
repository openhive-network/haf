CREATE CAST (hive.operation AS hive.comment_operation)
  WITH FUNCTION hive._operation_to_comment_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.comment_options_operation)
  WITH FUNCTION hive._operation_to_comment_options_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.vote_operation)
  WITH FUNCTION hive._operation_to_vote_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.witness_set_properties_operation)
  WITH FUNCTION hive._operation_to_witness_set_properties_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.account_create_operation)
  WITH FUNCTION hive._operation_to_account_create_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.account_create_with_delegation_operation)
  WITH FUNCTION hive._operation_to_account_create_with_delegation_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.account_update2_operation)
  WITH FUNCTION hive._operation_to_account_update2_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.account_update_operation)
  WITH FUNCTION hive._operation_to_account_update_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.account_witness_proxy_operation)
  WITH FUNCTION hive._operation_to_account_witness_proxy_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.account_witness_vote_operation)
  WITH FUNCTION hive._operation_to_account_witness_vote_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.cancel_transfer_from_savings_operation)
  WITH FUNCTION hive._operation_to_cancel_transfer_from_savings_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.change_recovery_account_operation)
  WITH FUNCTION hive._operation_to_change_recovery_account_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.claim_account_operation)
  WITH FUNCTION hive._operation_to_claim_account_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.claim_reward_balance_operation)
  WITH FUNCTION hive._operation_to_claim_reward_balance_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.collateralized_convert_operation)
  WITH FUNCTION hive._operation_to_collateralized_convert_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.convert_operation)
  WITH FUNCTION hive._operation_to_convert_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.create_claimed_account_operation)
  WITH FUNCTION hive._operation_to_create_claimed_account_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.custom_binary_operation)
  WITH FUNCTION hive._operation_to_custom_binary_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.custom_json_operation)
  WITH FUNCTION hive._operation_to_custom_json_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.custom_operation)
  WITH FUNCTION hive._operation_to_custom_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.decline_voting_rights_operation)
  WITH FUNCTION hive._operation_to_decline_voting_rights_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.delegate_vesting_shares_operation)
  WITH FUNCTION hive._operation_to_delegate_vesting_shares_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.delete_comment_operation)
  WITH FUNCTION hive._operation_to_delete_comment_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.escrow_approve_operation)
  WITH FUNCTION hive._operation_to_escrow_approve_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.escrow_dispute_operation)
  WITH FUNCTION hive._operation_to_escrow_dispute_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.escrow_release_operation)
  WITH FUNCTION hive._operation_to_escrow_release_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.escrow_transfer_operation)
  WITH FUNCTION hive._operation_to_escrow_transfer_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.feed_publish_operation)
  WITH FUNCTION hive._operation_to_feed_publish_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.limit_order_cancel_operation)
  WITH FUNCTION hive._operation_to_limit_order_cancel_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.limit_order_create2_operation)
  WITH FUNCTION hive._operation_to_limit_order_create2_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.limit_order_create_operation)
  WITH FUNCTION hive._operation_to_limit_order_create_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.pow2_operation)
  WITH FUNCTION hive._operation_to_pow2_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.pow_operation)
  WITH FUNCTION hive._operation_to_pow_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.recover_account_operation)
  WITH FUNCTION hive._operation_to_recover_account_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.recurrent_transfer_operation)
  WITH FUNCTION hive._operation_to_recurrent_transfer_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.request_account_recovery_operation)
  WITH FUNCTION hive._operation_to_request_account_recovery_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.reset_account_operation)
  WITH FUNCTION hive._operation_to_reset_account_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.set_reset_account_operation)
  WITH FUNCTION hive._operation_to_set_reset_account_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.set_withdraw_vesting_route_operation)
  WITH FUNCTION hive._operation_to_set_withdraw_vesting_route_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.transfer_from_savings_operation)
  WITH FUNCTION hive._operation_to_transfer_from_savings_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.transfer_operation)
  WITH FUNCTION hive._operation_to_transfer_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.transfer_to_savings_operation)
  WITH FUNCTION hive._operation_to_transfer_to_savings_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.transfer_to_vesting_operation)
  WITH FUNCTION hive._operation_to_transfer_to_vesting_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.withdraw_vesting_operation)
  WITH FUNCTION hive._operation_to_withdraw_vesting_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.witness_update_operation)
  WITH FUNCTION hive._operation_to_witness_update_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.create_proposal_operation)
  WITH FUNCTION hive._operation_to_create_proposal_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.proposal_pay_operation)
  WITH FUNCTION hive._operation_to_proposal_pay_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.remove_proposal_operation)
  WITH FUNCTION hive._operation_to_remove_proposal_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.update_proposal_operation)
  WITH FUNCTION hive._operation_to_update_proposal_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.update_proposal_votes_operation)
  WITH FUNCTION hive._operation_to_update_proposal_votes_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.account_created_operation)
  WITH FUNCTION hive._operation_to_account_created_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.author_reward_operation)
  WITH FUNCTION hive._operation_to_author_reward_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.changed_recovery_account_operation)
  WITH FUNCTION hive._operation_to_changed_recovery_account_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.clear_null_account_balance_operation)
  WITH FUNCTION hive._operation_to_clear_null_account_balance_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.comment_benefactor_reward_operation)
  WITH FUNCTION hive._operation_to_comment_benefactor_reward_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.comment_payout_update_operation)
  WITH FUNCTION hive._operation_to_comment_payout_update_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.comment_reward_operation)
  WITH FUNCTION hive._operation_to_comment_reward_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.consolidate_treasury_balance_operation)
  WITH FUNCTION hive._operation_to_consolidate_treasury_balance_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.curation_reward_operation)
  WITH FUNCTION hive._operation_to_curation_reward_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.delayed_voting_operation)
  WITH FUNCTION hive._operation_to_delayed_voting_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.effective_comment_vote_operation)
  WITH FUNCTION hive._operation_to_effective_comment_vote_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.expired_account_notification_operation)
  WITH FUNCTION hive._operation_to_expired_account_notification_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.failed_recurrent_transfer_operation)
  WITH FUNCTION hive._operation_to_failed_recurrent_transfer_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.fill_collateralized_convert_request_operation)
  WITH FUNCTION hive._operation_to_fill_collateralized_convert_request_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.fill_convert_request_operation)
  WITH FUNCTION hive._operation_to_fill_convert_request_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.fill_order_operation)
  WITH FUNCTION hive._operation_to_fill_order_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.fill_recurrent_transfer_operation)
  WITH FUNCTION hive._operation_to_fill_recurrent_transfer_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.fill_transfer_from_savings_operation)
  WITH FUNCTION hive._operation_to_fill_transfer_from_savings_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.fill_vesting_withdraw_operation)
  WITH FUNCTION hive._operation_to_fill_vesting_withdraw_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.hardfork_hive_operation)
  WITH FUNCTION hive._operation_to_hardfork_hive_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.hardfork_hive_restore_operation)
  WITH FUNCTION hive._operation_to_hardfork_hive_restore_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.hardfork_operation)
  WITH FUNCTION hive._operation_to_hardfork_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.ineffective_delete_comment_operation)
  WITH FUNCTION hive._operation_to_ineffective_delete_comment_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.interest_operation)
  WITH FUNCTION hive._operation_to_interest_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.limit_order_cancelled_operation)
  WITH FUNCTION hive._operation_to_limit_order_cancelled_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.liquidity_reward_operation)
  WITH FUNCTION hive._operation_to_liquidity_reward_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.pow_reward_operation)
  WITH FUNCTION hive._operation_to_pow_reward_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.producer_reward_operation)
  WITH FUNCTION hive._operation_to_producer_reward_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.return_vesting_delegation_operation)
  WITH FUNCTION hive._operation_to_return_vesting_delegation_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.shutdown_witness_operation)
  WITH FUNCTION hive._operation_to_shutdown_witness_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.system_warning_operation)
  WITH FUNCTION hive._operation_to_system_warning_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.transfer_to_vesting_completed_operation)
  WITH FUNCTION hive._operation_to_transfer_to_vesting_completed_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.vesting_shares_split_operation)
  WITH FUNCTION hive._operation_to_vesting_shares_split_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.witness_block_approve_operation)
  WITH FUNCTION hive._operation_to_witness_block_approve_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.dhf_funding_operation)
  WITH FUNCTION hive._operation_to_dhf_funding_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.dhf_conversion_operation)
  WITH FUNCTION hive._operation_to_dhf_conversion_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.producer_missed_operation)
  WITH FUNCTION hive._operation_to_producer_missed_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.proposal_fee_operation)
  WITH FUNCTION hive._operation_to_proposal_fee_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.collateralized_convert_immediate_conversion_operation)
  WITH FUNCTION hive._operation_to_collateralized_convert_immediate_conversion_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.escrow_approved_operation)
  WITH FUNCTION hive._operation_to_escrow_approved_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.escrow_rejected_operation)
  WITH FUNCTION hive._operation_to_escrow_rejected_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.proxy_cleared_operation)
  WITH FUNCTION hive._operation_to_proxy_cleared_operation
  AS ASSIGNMENT;

CREATE CAST (hive.operation AS hive.declined_voting_rights_operation)
  WITH FUNCTION hive._operation_to_declined_voting_rights_operation
  AS ASSIGNMENT;
