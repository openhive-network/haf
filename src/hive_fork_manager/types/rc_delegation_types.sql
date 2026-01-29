DROP TYPE IF EXISTS hive.rc_delegation_record CASCADE;
CREATE TYPE hive.rc_delegation_record AS (
  from_account TEXT,
  to_account TEXT,
  max_rc BIGINT
);

CREATE OR REPLACE FUNCTION hive.parse_rc_delegation(
  json_text TEXT
) RETURNS SETOF hive.rc_delegation_record
LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'parse_rc_delegation';
