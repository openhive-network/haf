CREATE OR REPLACE FUNCTION hive.get_legacy_style_operation(IN _operation_body text)
RETURNS JSON
AS 'MODULE_PATHNAME', 'get_legacy_style_operation' LANGUAGE C;