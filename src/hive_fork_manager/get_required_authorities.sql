DROP TYPE IF EXISTS hive.get_required_authorities_return_type CASCADE;
CREATE TYPE hive.get_required_authorities_return_type AS
(
  account_name TEXT,
  role TEXT
);

DROP FUNCTION IF EXISTS hive.get_required_authorities;
CREATE OR REPLACE FUNCTION hive.get_required_authorities(IN _operation_body hafd.operation)
RETURNS SETOF hive.get_required_authorities_return_type
AS 'MODULE_PATHNAME', 'get_required_authorities' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.get_required_authorities(IN _operation_body text)
    RETURNS SETOF hive.get_required_authorities_return_type
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
  RETURN QUERY SELECT * FROM hive.get_required_authorities((_operation_body::jsonb)::hafd.operation);
END
$$;

CREATE OR REPLACE FUNCTION hive.get_required_authorities(IN _operation_body jsonb)
    RETURNS SETOF hive.get_required_authorities_return_type
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
  RETURN QUERY SELECT * FROM hive.get_required_authorities((_operation_body)::hafd.operation);
END
$$;
