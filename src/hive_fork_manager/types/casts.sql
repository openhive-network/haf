CREATE OR REPLACE FUNCTION hive._operation_to_comment_operation(
  hive.operation
) RETURNS hive.comment_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_operation';

CREATE CAST (hive.operation AS hive.comment_operation)
  WITH FUNCTION hive._operation_to_comment_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_comment_options_operation(
  hive.operation
) RETURNS hive.comment_options_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_comment_options_operation';

CREATE CAST (hive.operation AS hive.comment_options_operation)
  WITH FUNCTION hive._operation_to_comment_options_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_vote_operation(
  hive.operation
) RETURNS hive.vote_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_vote_operation';

CREATE CAST (hive.operation AS hive.vote_operation)
  WITH FUNCTION hive._operation_to_vote_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_witness_set_properties_operation(
  hive.operation
) RETURNS hive.witness_set_properties_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_witness_set_properties_operation';

CREATE CAST (hive.operation AS hive.witness_set_properties_operation)
  WITH FUNCTION hive._operation_to_witness_set_properties_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_create_operation(
  hive.operation
) RETURNS hive.account_create_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_create_operation';

CREATE CAST (hive.operation AS hive.account_create_operation)
  WITH FUNCTION hive._operation_to_account_create_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_create_with_delegation_operation(
  hive.operation
) RETURNS hive.account_create_with_delegation_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_create_with_delegation_operation';

CREATE CAST (hive.operation AS hive.account_create_with_delegation_operation)
  WITH FUNCTION hive._operation_to_account_create_with_delegation_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_update2_operation(
  hive.operation
) RETURNS hive.account_update2_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_update2_operation';

CREATE CAST (hive.operation AS hive.account_update2_operation)
  WITH FUNCTION hive._operation_to_account_update2_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_update_operation(
  hive.operation
) RETURNS hive.account_update_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_update_operation';

CREATE CAST (hive.operation AS hive.account_update_operation)
  WITH FUNCTION hive._operation_to_account_update_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_witness_proxy_operation(
  hive.operation
) RETURNS hive.account_witness_proxy_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_witness_proxy_operation';

CREATE CAST (hive.operation AS hive.account_witness_proxy_operation)
  WITH FUNCTION hive._operation_to_account_witness_proxy_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_account_witness_vote_operation(
  hive.operation
) RETURNS hive.account_witness_vote_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_account_witness_vote_operation';

CREATE CAST (hive.operation AS hive.account_witness_vote_operation)
  WITH FUNCTION hive._operation_to_account_witness_vote_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_cancel_transfer_from_savings_operation(
  hive.operation
) RETURNS hive.cancel_transfer_from_savings_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_cancel_transfer_from_savings_operation';

CREATE CAST (hive.operation AS hive.cancel_transfer_from_savings_operation)
  WITH FUNCTION hive._operation_to_cancel_transfer_from_savings_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_change_recovery_account_operation(
  hive.operation
) RETURNS hive.change_recovery_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_change_recovery_account_operation';

CREATE CAST (hive.operation AS hive.change_recovery_account_operation)
  WITH FUNCTION hive._operation_to_change_recovery_account_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_claim_account_operation(
  hive.operation
) RETURNS hive.claim_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_claim_account_operation';

CREATE CAST (hive.operation AS hive.claim_account_operation)
  WITH FUNCTION hive._operation_to_claim_account_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_claim_reward_balance_operation(
  hive.operation
) RETURNS hive.claim_reward_balance_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_claim_reward_balance_operation';

CREATE CAST (hive.operation AS hive.claim_reward_balance_operation)
  WITH FUNCTION hive._operation_to_claim_reward_balance_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_collateralized_convert_operation(
  hive.operation
) RETURNS hive.collateralized_convert_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_collateralized_convert_operation';

CREATE CAST (hive.operation AS hive.collateralized_convert_operation)
  WITH FUNCTION hive._operation_to_collateralized_convert_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_convert_operation(
  hive.operation
) RETURNS hive.convert_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_convert_operation';

CREATE CAST (hive.operation AS hive.convert_operation)
  WITH FUNCTION hive._operation_to_convert_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_create_claimed_account_operation(
  hive.operation
) RETURNS hive.create_claimed_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_create_claimed_account_operation';

CREATE CAST (hive.operation AS hive.create_claimed_account_operation)
  WITH FUNCTION hive._operation_to_create_claimed_account_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_custom_binary_operation(
  hive.operation
) RETURNS hive.custom_binary_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_custom_binary_operation';

CREATE CAST (hive.operation AS hive.custom_binary_operation)
  WITH FUNCTION hive._operation_to_custom_binary_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_custom_json_operation(
  hive.operation
) RETURNS hive.custom_json_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_custom_json_operation';

CREATE CAST (hive.operation AS hive.custom_json_operation)
  WITH FUNCTION hive._operation_to_custom_json_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_custom_operation(
  hive.operation
) RETURNS hive.custom_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_custom_operation';

CREATE CAST (hive.operation AS hive.custom_operation)
  WITH FUNCTION hive._operation_to_custom_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_decline_voting_rights_operation(
  hive.operation
) RETURNS hive.decline_voting_rights_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_decline_voting_rights_operation';

CREATE CAST (hive.operation AS hive.decline_voting_rights_operation)
  WITH FUNCTION hive._operation_to_decline_voting_rights_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_delegate_vesting_shares_operation(
  hive.operation
) RETURNS hive.delegate_vesting_shares_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_delegate_vesting_shares_operation';

CREATE CAST (hive.operation AS hive.delegate_vesting_shares_operation)
  WITH FUNCTION hive._operation_to_delegate_vesting_shares_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_delete_comment_operation(
  hive.operation
) RETURNS hive.delete_comment_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_delete_comment_operation';

CREATE CAST (hive.operation AS hive.delete_comment_operation)
  WITH FUNCTION hive._operation_to_delete_comment_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_approve_operation(
  hive.operation
) RETURNS hive.escrow_approve_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_approve_operation';

CREATE CAST (hive.operation AS hive.escrow_approve_operation)
  WITH FUNCTION hive._operation_to_escrow_approve_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_dispute_operation(
  hive.operation
) RETURNS hive.escrow_dispute_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_dispute_operation';

CREATE CAST (hive.operation AS hive.escrow_dispute_operation)
  WITH FUNCTION hive._operation_to_escrow_dispute_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_release_operation(
  hive.operation
) RETURNS hive.escrow_release_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_release_operation';

CREATE CAST (hive.operation AS hive.escrow_release_operation)
  WITH FUNCTION hive._operation_to_escrow_release_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_escrow_transfer_operation(
  hive.operation
) RETURNS hive.escrow_transfer_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_escrow_transfer_operation';

CREATE CAST (hive.operation AS hive.escrow_transfer_operation)
  WITH FUNCTION hive._operation_to_escrow_transfer_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_feed_publish_operation(
  hive.operation
) RETURNS hive.feed_publish_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_feed_publish_operation';

CREATE CAST (hive.operation AS hive.feed_publish_operation)
  WITH FUNCTION hive._operation_to_feed_publish_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_limit_order_cancel_operation(
  hive.operation
) RETURNS hive.limit_order_cancel_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_limit_order_cancel_operation';

CREATE CAST (hive.operation AS hive.limit_order_cancel_operation)
  WITH FUNCTION hive._operation_to_limit_order_cancel_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_limit_order_create2_operation(
  hive.operation
) RETURNS hive.limit_order_create2_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_limit_order_create2_operation';

CREATE CAST (hive.operation AS hive.limit_order_create2_operation)
  WITH FUNCTION hive._operation_to_limit_order_create2_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_limit_order_create_operation(
  hive.operation
) RETURNS hive.limit_order_create_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_limit_order_create_operation';

CREATE CAST (hive.operation AS hive.limit_order_create_operation)
  WITH FUNCTION hive._operation_to_limit_order_create_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_pow2_operation(
  hive.operation
) RETURNS hive.pow2_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_pow2_operation';

CREATE CAST (hive.operation AS hive.pow2_operation)
  WITH FUNCTION hive._operation_to_pow2_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_pow_operation(
  hive.operation
) RETURNS hive.pow_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_pow_operation';

CREATE CAST (hive.operation AS hive.pow_operation)
  WITH FUNCTION hive._operation_to_pow_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_recover_account_operation(
  hive.operation
) RETURNS hive.recover_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_recover_account_operation';

CREATE CAST (hive.operation AS hive.recover_account_operation)
  WITH FUNCTION hive._operation_to_recover_account_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_recurrent_transfer_operation(
  hive.operation
) RETURNS hive.recurrent_transfer_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_recurrent_transfer_operation';

CREATE CAST (hive.operation AS hive.recurrent_transfer_operation)
  WITH FUNCTION hive._operation_to_recurrent_transfer_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_request_account_recovery_operation(
  hive.operation
) RETURNS hive.request_account_recovery_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_request_account_recovery_operation';

CREATE CAST (hive.operation AS hive.request_account_recovery_operation)
  WITH FUNCTION hive._operation_to_request_account_recovery_operation
  AS ASSIGNMENT;

CREATE OR REPLACE FUNCTION hive._operation_to_reset_account_operation(
  hive.operation
) RETURNS hive.reset_account_operation LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'operation_to_reset_account_operation';

CREATE CAST (hive.operation AS hive.reset_account_operation)
  WITH FUNCTION hive._operation_to_reset_account_operation
  AS ASSIGNMENT;
