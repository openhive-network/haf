DO
$$
    BEGIN
        CREATE TYPE hive.authority_type AS ENUM( 'OWNER', 'ACTIVE', 'POSTING', 'WITNESS', 'NEW_OWNER_AUTHORITY', 'RECENT_OWNER_AUTHORITY');
        EXCEPTION
            WHEN duplicate_object THEN null;
    END
$$;


DO
$$
    BEGIN
        CREATE TYPE hive.keyauth_record_type AS
        (
              key_auth TEXT
            , authority_kind hive.authority_type
            , account_name TEXT
        );
    END
$$;

DO
$$
    BEGIN
        CREATE TYPE hive.keyauth_c_record_type AS
        (
              key_auth TEXT
            , authority_c_kind INTEGER
            , account_name TEXT
        );
    END
$$;

CREATE OR REPLACE FUNCTION hive.get_keyauths_wrapper(IN _operation_body text)
RETURNS SETOF hive.keyauth_c_record_type
AS '$libdir/libhfm-@GIT_REVISION@.so', 'get_keyauths_wrapped' LANGUAGE C;


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


CREATE OR REPLACE FUNCTION hive.get_keyauths(IN _operation_body text)
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

CREATE OR REPLACE FUNCTION hive.get_keyauths_operations()
RETURNS SETOF TEXT
LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
RETURN QUERY 
SELECT 'account_create_operation'
UNION ALL
SELECT 'account_create_with_delegation_operation'
UNION ALL
SELECT 'account_update_operation'
UNION ALL
SELECT 'account_update2_operation'
UNION ALL
SELECT 'create_claimed_account_operation'
UNION ALL
SELECT 'recover_account_operation'
UNION ALL
SELECT 'reset_account_operation'
UNION ALL
SELECT 'request_account_recovery_operation'
UNION ALL
SELECT 'witness_set_properties_operation'
;
END
$$;

CREATE OR REPLACE FUNCTION hive.is_keyauths_operation(IN _full_op TEXT)
RETURNS Boolean
LANGUAGE plpgsql
IMMUTABLE
AS
$$
DECLARE
    __j JSON;
    __op TEXT;
BEGIN
    BEGIN
        __j := _full_op AS JSON;
    EXCEPTION   
        WHEN others THEN
        RETURN false;
    END;
    __op := json_extract_path(__j, 'type');
    RETURN EXISTS(SELECT * FROM  hive.get_keyauths_operations() WHERE BTRIM(__op, '"') =  get_keyauths_operations);
END
$$;
