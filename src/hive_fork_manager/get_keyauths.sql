DROP FUNCTION IF EXISTS hive.get_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_keyauths_wrapper(IN _operation_body hive.operation)
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_genesis_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_genesis_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_genesis_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_hf09_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_hf09_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_hf09_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_hf21_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_hf21_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_hf21_keyauths_wrapped' LANGUAGE C;

DROP FUNCTION IF EXISTS hive.get_hf24_keyauths_wrapper;
CREATE OR REPLACE FUNCTION hive.get_hf24_keyauths_wrapper()
RETURNS SETOF hive.keyauth_c_record_type
AS 'MODULE_PATHNAME', 'get_hf24_keyauths_wrapped' LANGUAGE C;

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
        account_auth,
        weight_threshold,
        w
    FROM hive.get_keyauths_wrapper(_operation_body);
END
$$;

DROP FUNCTION IF EXISTS hive.get_genesis_keyauths;
CREATE OR REPLACE FUNCTION hive.get_genesis_keyauths()
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
        account_auth,
        weight_threshold,
        w
    FROM hive.get_genesis_keyauths_wrapper();
END
$$;

DROP FUNCTION IF EXISTS hive.get_hf09_keyauths;
CREATE OR REPLACE FUNCTION hive.get_hf09_keyauths()
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
        account_auth,
        weight_threshold,
        w
    FROM hive.get_hf09_keyauths_wrapper();
END
$$;

DROP FUNCTION IF EXISTS hive.get_hf21_keyauths;
CREATE OR REPLACE FUNCTION hive.get_hf21_keyauths()
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
        account_auth,
        weight_threshold,
        w
    FROM hive.get_hf21_keyauths_wrapper();
END
$$;

DROP FUNCTION IF EXISTS hive.get_hf24_keyauths;
CREATE OR REPLACE FUNCTION hive.get_hf24_keyauths()
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
        account_auth,
        weight_threshold,
        w
    FROM hive.get_hf24_keyauths_wrapper();
END
$$;

DROP FUNCTION IF EXISTS hive.is_keyauths_operation;
