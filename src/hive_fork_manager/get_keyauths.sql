DROP TYPE IF EXISTS hive.authority_type CASCADE;
CREATE TYPE hive.authority_type AS ENUM( 'OWNER', 'ACTIVE', 'POSTING', 'WITNESS', 'NEW_OWNER_AUTHORITY', 'RECENT_OWNER_AUTHORITY');


DROP TYPE IF EXISTS hive.keyauth_record_type CASCADE;
CREATE TYPE hive.keyauth_record_type AS
(
      key_auth TEXT
    , authority_kind hive.authority_type
    , account_name TEXT
);

DROP TYPE IF EXISTS hive.keyauth_c_record_type CASCADE;
CREATE TYPE hive.keyauth_c_record_type AS
(
      key_auth TEXT
    , authority_c_kind INTEGER
    , account_name TEXT
);

DROP FUNCTION IF EXISTS hive.get_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_keyauths_wrapper(IN _operation_body hive.operation)
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.authority_type_c_int_to_enum;
CREATE OR REPLACE FUNCTION hive.authority_type_c_int_to_enum(IN _pos integer)
RETURNS hive.authority_type
LANGUAGE plpgsql
IMMUTABLE
AS
$$
DECLARE
    __arr hive.authority_type []:= enum_range(null::hive.authority_type);
BEGIN
    return __arr[_pos + 1];
END
$$;

DROP FUNCTION IF EXISTS hive.get_keyauths;
CREATE OR REPLACE FUNCTION hive.get_keyauths(IN _operation_body hive.operation)
RETURNS SETOF hive.keyauth_record_type
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT 
        key_auth , 
        hive.authority_type_c_int_to_enum(authority_c_kind), 
        account_name 
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

DROP FUNCTION IF EXISTS hive.is_keyauths_operation;
CREATE OR REPLACE FUNCTION hive.is_keyauths_operation(IN _operation_body hive.operation)
RETURNS Boolean
AS 'MODULE_PATHNAME', 'is_keyauths_operation' LANGUAGE C;
