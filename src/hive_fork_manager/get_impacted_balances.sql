DO
$$
BEGIN
  CREATE TYPE hive.impacted_balances_return AS
  (
    account_name VARCHAR, -- Name of the account impacted by given operation  
    amount BIGINT, -- Amount of tokens changed by operation. Positive if account balance (specific to given asset_symbol_nai) should be incremented, negative if decremented
    asset_precision INT, -- Precision of assets (probably only for future cases when custom tokens will be available)
    asset_symbol_nai INT -- Type of asset symbol used in the operation
  );
  EXCEPTION
    WHEN duplicate_object THEN null;
END
$$;

CREATE OR REPLACE FUNCTION hive.get_impacted_balances(IN _operation_body text, IN _is_hf01 bool)
RETURNS SETOF impacted_balances_return
AS '$libdir/libhfm-@GIT_REVISION@.so', 'get_impacted_balances' LANGUAGE C;

--- Returns set of operations which impact account balances.
CREATE OR REPLACE FUNCTION hive.get_balance_impacting_operations()
RETURNS SETOF TEXT
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
RETURN QUERY 
SELECT 'hive::protocol::fill_vesting_withdraw_operation'
UNION ALL
SELECT 'hive::protocol::producer_reward_operation'
UNION ALL
SELECT 'hive::protocol::claim_account_operation'
UNION ALL
SELECT 'hive::protocol::account_create_operation'
UNION ALL
SELECT 'hive::protocol::account_create_with_delegation_operation'
UNION ALL
SELECT 'hive::protocol::hardfork_hive_restore_operation'
UNION ALL
SELECT 'hive::protocol::fill_recurrent_transfer_operation'
UNION ALL
SELECT 'hive::protocol::fill_transfer_from_savings_operation'
UNION ALL
SELECT 'hive::protocol::liquidity_reward_operation'
UNION ALL
SELECT 'hive::protocol::fill_convert_request_operation'
UNION ALL
SELECT 'hive::protocol::fill_collateralized_convert_request_operation'
UNION ALL
SELECT 'hive::protocol::escrow_transfer_operation'
UNION ALL
SELECT 'hive::protocol::escrow_release_operation'
UNION ALL
SELECT 'hive::protocol::transfer_operation'
--UNION ALL -- Ignore in favor to transfer_to_vesting_completed_operation
--SELECT 'hive::protocol::transfer_to_vesting_operation'
UNION ALL
SELECT 'hive::protocol::transfer_to_vesting_completed_operation'
UNION ALL
SELECT 'hive::protocol::pow_reward_operation'
UNION ALL
SELECT 'hive::protocol::limit_order_create_operation'
UNION ALL
SELECT 'hive::protocol::limit_order_create2_operation'
UNION ALL
SELECT 'hive::protocol::fill_order_operation'
UNION ALL
SELECT 'hive::protocol::limit_order_cancelled_operation'
UNION ALL
SELECT 'hive::protocol::transfer_to_savings_operation'
UNION ALL
SELECT 'hive::protocol::claim_reward_balance_operation'
UNION ALL
SELECT 'hive::protocol::proposal_pay_operation'
UNION ALL
SELECT 'hive::protocol::sps_convert_operation'
UNION ALL
SELECT 'hive::protocol::author_reward_operation'
UNION ALL
SELECT 'hive::protocol::curation_reward_operation'
UNION ALL
SELECT 'hive::protocol::account_created_operation'
UNION ALL
SELECT 'hive::protocol::interest_operation'
;
END
$$;