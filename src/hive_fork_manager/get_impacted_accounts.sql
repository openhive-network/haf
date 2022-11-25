CREATE OR REPLACE FUNCTION hive.get_impacted_accounts(IN text)
RETURNS SETOF text AS 'MODULE_PATHNAME', 'get_impacted_accounts' LANGUAGE C;
