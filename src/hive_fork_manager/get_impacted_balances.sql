DROP TYPE IF EXISTS hive.impacted_balances_return CASCADE;
CREATE TYPE hive.impacted_balances_return AS
(
  account_name VARCHAR, -- Name of the account impacted by given operation  
  amount BIGINT, -- Amount of tokens changed by operation. Positive if account balance (specific to given asset_symbol_nai) should be incremented, negative if decremented
  asset_precision INT, -- Precision of assets (probably only for future cases when custom tokens will be available)
  asset_symbol_nai INT -- Type of asset symbol used in the operation
);

CREATE OR REPLACE FUNCTION hive.get_impacted_balances(IN _operation_body text, IN _is_hf01 bool)
RETURNS SETOF impacted_balances_return
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so', 'get_impacted_balances' LANGUAGE C;

--- Returns set of operations which impact account balances.



DROP TYPE IF EXISTS hive.get_balance_impacting_operations_return_type CASCADE;
CREATE TYPE hive.get_balance_impacting_operations_return_type AS
(
  get_balance_impacting_operations TEXT
);

CREATE OR REPLACE FUNCTION hive.get_balance_impacting_operations()
RETURNS SETOF hive.get_balance_impacting_operations_return_type
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so', 'get_balance_impacting_operations' LANGUAGE C;
