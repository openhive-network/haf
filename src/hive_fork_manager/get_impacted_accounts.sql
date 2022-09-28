CREATE OR REPLACE FUNCTION hive.get_impacted_accounts(IN text)
RETURNS SETOF text AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so', 'get_impacted_accounts' LANGUAGE C;
