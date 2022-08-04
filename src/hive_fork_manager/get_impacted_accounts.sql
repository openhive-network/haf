CREATE OR REPLACE FUNCTION hive.get_impacted_accounts(IN hive.operation)
RETURNS SETOF text AS 'MODULE_PATHNAME', 'get_impacted_accounts' LANGUAGE C;
