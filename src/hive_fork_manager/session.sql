CREATE OR REPLACE FUNCTION hive.sessions_reconnect()
RETURNS VOID
LANGUAGE plpgsql
AS
$$
DECLARE
  __session RECORD;
  __reconnect_string TEXT;
  __session_handle BIGINT;
BEGIN
  FOR __session IN SELECT name, params FROM hive.sessions
  LOOP
    __reconnect_string := __session.params ->> 'reconnect_string';

    RAISE NOTICE 'Executing reconnect function for session: %', __session.name;

    RAISE NOTICE 'reconnect string is %', __reconnect_string;
    EXECUTE __reconnect_string INTO __session_handle; -- mtlk security issue ?
    RAISE NOTICE 'Reconnect function execution completed for session: %. Returned value: %', __session.name, __session_handle;

    -- update the session_handle field in the params column
    UPDATE hive.sessions
    SET params = jsonb_set(params::jsonb, '{session_handle}', to_jsonb(__session_handle::bigint))
    WHERE name = __session.name;

    RAISE NOTICE 'Updated session_handle for session: % after reconnect function execution', __session.name;
  END LOOP;
END;
$$
;


CREATE OR REPLACE FUNCTION hive.sessions_disconnect()
RETURNS VOID
LANGUAGE plpgsql
AS
$$
DECLARE
    __session RECORD;
    __func_to_exec TEXT;
    __session_handle_param BIGINT;
    __to_execute TEXT;
BEGIN
    FOR __session IN SELECT name, params FROM hive.sessions LOOP
        __func_to_exec := __session.params ->> 'disconnect_function';
        __session_handle_param := __session.params -> 'session_handle';

        RAISE NOTICE 'Processing session: %, function: %, session handle: %', __session.name, __func_to_exec, __session_handle_param;

        IF __func_to_exec IS NOT NULL THEN
            RAISE NOTICE 'Executing function: % with session handle: %', __func_to_exec, __session_handle_param;
            __to_execute = format(__func_to_exec, __session_handle_param);
            RAISE NOTICE '__to_execute1=%', __to_execute;
            EXECUTE __to_execute;
            RAISE NOTICE 'Function % executed successfully', __func_to_exec;
        ELSE
            RAISE NOTICE 'No function to execute for session: %', __session.name;
        END IF;
    END LOOP;
END;
$$
;



CREATE OR REPLACE FUNCTION hive.create_session(IN _name TEXT, IN _params JSONB)--IN shared_memory_bin_path TEXT, IN _postgres_url TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$$
DECLARE
    _debug_msg JSON;
BEGIN

  -- Display hive.sessions table before insert
    SELECT INTO _debug_msg json_agg(row_to_json(t))
    FROM (SELECT name, params FROM hive.sessions) t;
    RAISE NOTICE 'Before insert: %', COALESCE(_debug_msg::text, 'hive.sessions is empty');

    INSERT INTO hive.sessions(name, params) VALUES (_name, _params);


    -- Display hive.sessions table after insert
    SELECT INTO _debug_msg json_agg(row_to_json(t))
    FROM (SELECT name, params FROM hive.sessions) t;
    RAISE NOTICE 'After insert: %', _debug_msg::text;

    RETURN TRUE;
END;
$$
;

CREATE OR REPLACE FUNCTION hive.get_session_ptr(IN _context TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS
$$
DECLARE
    __params JSONB;
    __session_ptr BIGINT;
BEGIN
    __params = (SELECT params FROM hive.sessions WHERE name = _context);
    __session_ptr = __params->'session_handle';
    return __session_ptr;
END;
$$
;


CREATE OR REPLACE FUNCTION hive.destroy_session(IN _name TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN
  DELETE FROM hive.sessions WHERE name = _name;
END;
$$
;


-------------------------- TESTS --------------------------

CREATE OR REPLACE FUNCTION hive.test_in_c_create_a_structure(str1 TEXT, str2 TEXT)
RETURNS BIGINT
AS 'MODULE_PATHNAME', 'test_in_c_create_a_structure' LANGUAGE C;

-- CREATE OR REPLACE FUNCTION hive.test_in_c_set_name(IN _session_ptr BIGINT, IN name TEXT)
-- RETURNS VOID
-- AS 'MODULE_PATHNAME', 'test_in_c_set_name' LANGUAGE C;

CREATE OR REPLACE FUNCTION hive.test_in_c_get_strings_sum(IN _session_ptr BIGINT)
RETURNS TEXT
AS 'MODULE_PATHNAME', 'test_in_c_get_strings_sum' LANGUAGE C;


CREATE OR REPLACE FUNCTION hive.test_in_c_destroy(IN _session_ptr BIGINT)
RETURNS VOID
AS 'MODULE_PATHNAME', 'test_in_c_destroy' LANGUAGE C;


