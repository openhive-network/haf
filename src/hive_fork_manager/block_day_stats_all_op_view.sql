--- View provides blockchain operation counts (including vops) per day.
CREATE OR REPLACE VIEW hive.block_day_stats_all_ops_view AS
SELECT * FROM crosstab(
$$
WITH op_day_stats AS
(
SELECT (o.block_num / 28800) AS block_day, o.op_type_id, COUNT(1)
FROM hive.operations o
GROUP BY 1, 2
),
supplemented_stats AS
(
SELECT d.block_day, t.op_type_id, COALESCE(ods.count, 0)::INT AS COUNT
FROM (SELECT DISTINCT block_day FROM op_day_stats) d
CROSS JOIN (SELECT ot.id AS op_type_id FROM hive.operation_types ot) t
LEFT JOIN op_day_stats ods ON ods.block_day = d.block_day AND ods.op_type_id = t.op_type_id
)
SELECT s.block_day::int, ot.name::text, s.count::int FROM supplemented_stats s
JOIN hive.operation_types ot on s.op_type_id = ot.id
ORDER BY s.block_day, ot.name
$$
,
$$ SELECT ot.name FROM hive.operation_types ot ORDER BY 1 $$ -- Must match the order with interface specification
) AS ct(block_day INT, 

-- This order must match to order used in above query listing all operations
account_create_operation INT,
account_create_with_delegation_operation INT,
account_created_operation INT,
account_update2_operation INT,
account_update_operation INT,
account_witness_proxy_operation INT,
account_witness_vote_operation INT,
author_reward_operation INT,
cancel_transfer_from_savings_operation INT,
change_recovery_account_operation INT,
changed_recovery_account_operation INT,
claim_account_operation INT,
claim_reward_balance_operation INT,
clear_null_account_balance_operation INT,
collateralized_convert_immediate_conversion_operation INT,
collateralized_convert_operation INT,
comment_benefactor_reward_operation INT,
comment_operation INT,
comment_options_operation INT,
comment_payout_update_operation INT,
comment_reward_operation INT,
consolidate_treasury_balance_operation INT,
convert_operation INT,
create_claimed_account_operation INT,
create_proposal_operation INT,
curation_reward_operation INT,
custom_binary_operation INT,
custom_json_operation INT,
custom_operation INT,
decline_voting_rights_operation INT,
delayed_voting_operation INT,
delegate_vesting_shares_operation INT,
delete_comment_operation INT,
dhf_conversion_operation INT,
dhf_funding_operation INT,
effective_comment_vote_operation INT,
escrow_approve_operation INT,
escrow_approved_operation INT,
escrow_dispute_operation INT,
escrow_rejected_operation INT,
escrow_release_operation INT,
escrow_transfer_operation INT,
expired_account_notification_operation INT,
failed_recurrent_transfer_operation INT,
feed_publish_operation INT,
fill_collateralized_convert_request_operation INT,
fill_convert_request_operation INT,
fill_order_operation INT,
fill_recurrent_transfer_operation INT,
fill_transfer_from_savings_operation INT,
fill_vesting_withdraw_operation INT,
hardfork_hive_operation INT,
hardfork_hive_restore_operation INT,
hardfork_operation INT,
ineffective_delete_comment_operation INT,
interest_operation INT,
limit_order_cancel_operation INT,
limit_order_cancelled_operation INT,
limit_order_create2_operation INT,
limit_order_create_operation INT,
liquidity_reward_operation INT,
pow2_operation INT,
pow_operation INT,
pow_reward_operation INT,
producer_missed_operation INT,
producer_reward_operation INT,
proposal_fee_operation INT,
proposal_pay_operation INT,
recover_account_operation INT,
recurrent_transfer_operation INT,
remove_proposal_operation INT,
request_account_recovery_operation INT,
reset_account_operation INT,
return_vesting_delegation_operation INT,
set_reset_account_operation INT,
set_withdraw_vesting_route_operation INT,
shutdown_witness_operation INT,
system_warning_operation INT,
transfer_from_savings_operation INT,
transfer_operation INT,
transfer_to_savings_operation INT,
transfer_to_vesting_completed_operation INT,
transfer_to_vesting_operation INT,
update_proposal_operation INT,
update_proposal_votes_operation INT,
vesting_shares_split_operation INT,
vote_operation INT,
withdraw_vesting_operation INT,
witness_block_approve_operation INT,
witness_set_properties_operation INT,
witness_update_operation INT
) 
;

