--- View provides blockchain operation counts (excluding vops) per day.
CREATE OR REPLACE VIEW hive.block_day_stats_view AS
SELECT * FROM crosstab(
$$
WITH op_day_stats AS
(
SELECT (o.block_num / 28800) AS block_day, o.op_type_id, COUNT(1)
FROM hive.operations o
WHERE o.op_type_id < (SELECT ot.id FROM hive.operation_types ot WHERE ot.is_virtual = TRUE ORDER BY ot.id LIMIT 1)
GROUP BY 1, 2
),
supplemented_stats AS
(
SELECT d.block_day, t.op_type_id, COALESCE(ods.count, 0)::INT AS COUNT
FROM (SELECT DISTINCT block_day FROM op_day_stats) d
CROSS JOIN (SELECT ot.id AS op_type_id FROM hive.operation_types ot WHERE is_virtual = FALSE) t
LEFT JOIN op_day_stats ods ON ods.block_day = d.block_day AND ods.op_type_id = t.op_type_id
)
SELECT s.block_day::int, ot.name::text, s.count::int FROM supplemented_stats s
JOIN hive.operation_types ot on s.op_type_id = ot.id
ORDER BY s.block_day, ot.name
$$
,
$$ SELECT ot.name FROM hive.operation_types ot WHERE ot.is_virtual = FALSE ORDER BY 1 $$ -- Must match the order with interface specification

) as ct(block_day INT, 
-- This order must match to order used in above query listing all operations
account_create_operation INT,
account_create_with_delegation_operation INT,
account_update2_operation INT,
account_update_operation INT,
account_witness_proxy_operation INT,
account_witness_vote_operation INT,
cancel_transfer_from_savings_operation INT,
change_recovery_account_operation INT,
claim_account_operation INT,
claim_reward_balance_operation INT,
collateralized_convert_operation INT,
comment_operation INT,
comment_options_operation INT,
convert_operation INT,
create_claimed_account_operation INT,
create_proposal_operation INT,
custom_binary_operation INT,
custom_json_operation INT,
custom_operation INT,
decline_voting_rights_operation INT,
delegate_vesting_shares_operation INT,
delete_comment_operation INT,
escrow_approve_operation INT,
escrow_dispute_operation INT,
escrow_release_operation INT,
escrow_transfer_operation INT,
feed_publish_operation INT,
limit_order_cancel_operation INT,
limit_order_create2_operation INT,
limit_order_create_operation INT,
pow2_operation INT,
pow_operation INT,
recover_account_operation INT,
recurrent_transfer_operation INT,
remove_proposal_operation INT,
request_account_recovery_operation INT,
reset_account_operation INT,
set_reset_account_operation INT,
set_withdraw_vesting_route_operation INT,
transfer_from_savings_operation INT,
transfer_operation INT,
transfer_to_savings_operation INT,
transfer_to_vesting_operation INT,
update_proposal_operation INT,
update_proposal_votes_operation INT,
vote_operation INT,
withdraw_vesting_operation INT,
witness_block_approve_operation INT,
witness_set_properties_operation INT,
witness_update_operation INT
);

