DROP TYPE IF EXISTS hive.rc_delegation_record CASCADE;
CREATE TYPE hive.rc_delegation_record AS (
  from_account TEXT,
  to_account TEXT,
  max_rc BIGINT
);

-- Parses delegate_rc_operation(s) embedded in json of custom_json_operation with id 'rc'. It only looks at the json,
-- so it cannot tell if the delegation was effective. hived reports each effective embedded delegation as separate
-- delegate_rc_operation (op_type_id 37), placed right after its custom_json_operation with the same op_pos (since
-- HF29 delegate_rc_operation can also be a direct part of transaction), so effective delegations can be taken from
-- operations instead.
CREATE OR REPLACE FUNCTION hive.parse_rc_delegation(
  json_text TEXT
) RETURNS SETOF hive.rc_delegation_record
LANGUAGE c IMMUTABLE STRICT PARALLEL SAFE
AS 'MODULE_PATHNAME',
'parse_rc_delegation';
