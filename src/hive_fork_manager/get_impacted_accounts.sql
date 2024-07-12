CREATE OR REPLACE FUNCTION hive.get_impacted_accounts(IN hive.operation)
RETURNS SETOF hive.ctext AS 'MODULE_PATHNAME', 'get_impacted_accounts' LANGUAGE C;
