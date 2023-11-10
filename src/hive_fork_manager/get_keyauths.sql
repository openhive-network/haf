DROP TYPE IF EXISTS hive.key_type CASCADE;
CREATE TYPE hive.key_type AS ENUM( 'OWNER', 'ACTIVE', 'POSTING', 'MEMO', 'WITNESS_SIGNING');


DROP TYPE IF EXISTS hive.keyauth_record_type CASCADE;
CREATE TYPE hive.keyauth_record_type AS
(
      account_name TEXT
    , key_kind hive.key_type
    , key_auth TEXT []
    , account_auth TEXT []
);

DROP TYPE IF EXISTS hive.keyauth_c_record_type CASCADE;
CREATE TYPE hive.keyauth_c_record_type AS
(
      account_name TEXT
    , authority_c_kind INTEGER
    , key_auth TEXT []
    , account_auth TEXT []
);

DROP FUNCTION IF EXISTS hive.get_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_keyauths_wrapper(IN _operation_body hive.operation)
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.key_type_c_int_to_enum;
CREATE OR REPLACE FUNCTION hive.key_type_c_int_to_enum(IN _pos integer)
RETURNS hive.key_type
LANGUAGE plpgsql
IMMUTABLE
AS
$$
DECLARE
    __arr hive.key_type []:= enum_range(null::hive.key_type);
BEGIN
    return __arr[_pos + 1];
END
$$;

CREATE OR REPLACE FUNCTION hive.public_key_to_string(p_key BYTEA)
RETURNS TEXT
AS 'MODULE_PATHNAME', 'public_key_to_string' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_keyauths;
CREATE OR REPLACE FUNCTION hive.get_keyauths(IN _operation_body hive.operation)
RETURNS SETOF hive.keyauth_record_type
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT 
        account_name,
        hive.key_type_c_int_to_enum(authority_c_kind), 
        key_auth,
        account_auth
        FROM hive.get_keyauths_wrapper(_operation_body);
END
$$;


DROP TYPE IF EXISTS hive.get_operations_type CASCADE;
CREATE TYPE hive.get_operations_type AS
(
      get_keyauths_operations TEXT
);

DROP FUNCTION IF EXISTS hive.get_keyauths_operations;
CREATE OR REPLACE FUNCTION hive.get_keyauths_operations()
RETURNS SETOF hive.get_operations_type
AS 'MODULE_PATHNAME', 'get_keyauths_operations' LANGUAGE C;
