-- Strip \u0000 JSON null-byte escape sequences from a JSON text string.
--
-- Respects backslash escaping: \\u0000 (escaped backslash + literal "u0000")
-- is preserved, while bare \u0000 (actual null-byte escape) is removed.
--
-- Use this when extracting JSON string values via ->> that may contain
-- \u0000 escapes, before casting to ::jsonb or storing in TEXT columns.
--
-- Returns NULL on NULL input (STRICT).
-- Returns the input unchanged when no \u0000 sequences are present.

CREATE OR REPLACE FUNCTION hive.strip_json_null_escapes( json_text TEXT )
RETURNS TEXT
LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME', 'strip_json_null_escapes';
