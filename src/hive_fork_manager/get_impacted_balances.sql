DROP TYPE IF EXISTS hive.impacted_balances_return CASCADE;
CREATE TYPE hive.impacted_balances_return AS
(
  account_name VARCHAR, -- Name of the account impacted by given operation  
  amount BIGINT, -- Amount of tokens changed by operation. Positive if account balance (specific to given asset_symbol_nai) should be incremented, negative if decremented
  asset_precision INT, -- Precision of assets (probably only for future cases when custom tokens will be available)
  asset_symbol_nai INT -- Type of asset symbol used in the operation
);

CREATE OR REPLACE FUNCTION hive.get_impacted_balances(IN _operation_body hive.operation, IN _is_hf01 bool)
RETURNS SETOF impacted_balances_return
AS 'MODULE_PATHNAME', 'get_impacted_balances' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.get_impacted_balances(IN _operation_body text, IN _is_hf01 bool)
  RETURNS SETOF impacted_balances_return
  LANGUAGE plpgsql
  VOLATILE
AS
$BODY$
BEGIN
  RETURN QUERY SELECT * FROM hive.get_impacted_balances(_operation_body::jsonb::hive.operation, _is_hf01);
END;
$BODY$
;

--- Returns set of operations which impact account balances.

CREATE OR REPLACE FUNCTION hive.get_impacted_balances(IN _operation_body hive.operation, IN _operation_block_number INT)
    RETURNS SETOF hive.impacted_balances_return
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
is_hf01 BOOLEAN := (SELECT (block_num < _operation_block_number) FROM hive.applied_hardforks WHERE hardfork_num = 1);
BEGIN

RETURN QUERY SELECT * FROM hive.get_impacted_balances(_operation_body, is_hf01);

END;
$BODY$
;


DROP TYPE IF EXISTS hive.get_balance_impacting_operations_return_type CASCADE;
CREATE TYPE hive.get_balance_impacting_operations_return_type AS
(
  get_balance_impacting_operations TEXT
);

DROP FUNCTION IF EXISTS hive.get_balance_impacting_operations;
CREATE OR REPLACE FUNCTION hive.get_balance_impacting_operations()
RETURNS SETOF hive.get_balance_impacting_operations_return_type
AS 'MODULE_PATHNAME', 'get_balance_impacting_operations' LANGUAGE C;
