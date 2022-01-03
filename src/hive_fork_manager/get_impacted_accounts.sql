CREATE OR REPLACE FUNCTION hive.get_impacted_accounts(IN text)
RETURNS SETOF text AS '$libdir/libhfm-@GIT_REVISION@.so', 'get_impacted_accounts' LANGUAGE C;
