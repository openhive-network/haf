CREATE OR REPLACE FUNCTION hive.get_legacy_style_operation(IN _operation_body text)
RETURNS JSON
AS '$libdir/libhfm-@HAF_GIT_REVISION_SHA@.so', 'get_legacy_style_operation' LANGUAGE C;