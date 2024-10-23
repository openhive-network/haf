CREATE TYPE hafd.key_type AS ENUM( 'OWNER', 'ACTIVE', 'POSTING', 'MEMO', 'WITNESS_SIGNING');

CREATE TYPE hive.key_type_c_int_to_enum AS
(
      account_name TEXT
    , key_kind hafd.key_type
    , key_auth BYTEA
    , account_auth TEXT
    , weight_threshold INTEGER
    , w INTEGER
);

CREATE OR REPLACE FUNCTION hafd.key_type_c_int_to_enum(IN _pos integer)
    RETURNS hafd.key_type
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
DECLARE
    __arr hafd.key_type []:= enum_range(null::hafd.key_type);
BEGIN
    return __arr[_pos + 1];
END
$$;


CREATE OR REPLACE FUNCTION hafd.get_keyauths(IN _operation_body hafd.operation)
    RETURNS SETOF hive.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hafd.key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_keyauths_wrapper(_operation_body);
END
$$;

CREATE OR REPLACE FUNCTION hafd.get_genesis_keyauths()
    RETURNS SETOF hive.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hafd.key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_genesis_keyauths_wrapper();
END
$$;

CREATE OR REPLACE FUNCTION hafd.get_hf09_keyauths()
    RETURNS SETOF hive.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hafd.key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_hf09_keyauths_wrapper();
END
$$;

CREATE OR REPLACE FUNCTION hafd.get_hf21_keyauths()
    RETURNS SETOF hive.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hafd.key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_hf21_keyauths_wrapper();
END
$$;

CREATE OR REPLACE FUNCTION hafd.get_hf24_keyauths()
    RETURNS SETOF hive.key_type_c_int_to_enum
    LANGUAGE plpgsql
    IMMUTABLE
AS
$$
BEGIN
    RETURN QUERY SELECT
                     account_name,
                     hafd.key_type_c_int_to_enum(authority_c_kind),
                     key_auth,
                     account_auth,
                     weight_threshold,
                     w
                 FROM hive.get_hf24_keyauths_wrapper();
END
$$;