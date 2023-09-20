CREATE OR REPLACE FUNCTION hive.session_setup(IN _session_name TEXT, IN _reconnect_string TEXT, IN _disconnect_function TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$$
DECLARE
    _debug_msg JSON = Null;
BEGIN

  -- Display hive.sessions table before insert
    SELECT INTO _debug_msg json_agg(row_to_json(t))
    FROM (SELECT * FROM hive.sessions) t;
    
    
    RAISE NOTICE 'Beforee insert: %', COALESCE((SELECT json_agg(row_to_json(t)) FROM (SELECT name, * FROM hive.sessions) t)::text, 'hive.sessions is empty');

    RAISE NOTICE 'Before insert: %', COALESCE(_debug_msg::text, 'hive.sessions is empty');

    INSERT INTO hive.sessions(name, reconnect_string, disconnect_function) VALUES (_session_name, _reconnect_string, _disconnect_function);

    -- Display hive.sessions table after insert
    SELECT INTO _debug_msg json_agg(row_to_json(t))
    FROM (SELECT * FROM hive.sessions) t;
    RAISE NOTICE 'After insert: %', _debug_msg::text;

    RETURN TRUE;
END;
$$
;

CREATE OR REPLACE FUNCTION hive.session_forget(IN _session_name TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN
  DELETE FROM hive.sessions WHERE name = _session_name;
END;
$$
;


CREATE OR REPLACE FUNCTION hive.session_managed_object_start(_session_name TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
DECLARE
  __reconnect_string TEXT;
  __session_handle BIGINT;
BEGIN

    RAISE NOTICE '0 in session_managed_object_start: %', COALESCE((SELECT json_agg(row_to_json(t)) FROM (SELECT * FROM hive.sessions) t)::text, 'hive.sessions is empty');

    RAISE NOTICE 'OOO %', (SELECT (name || reconnect_string || disconnect_function)  FROM hive.sessions     WHERE name = _session_name LIMIT 1) ;
    __reconnect_string = (SELECT reconnect_string  FROM hive.sessions     WHERE name = _session_name LIMIT 1) ;

    RAISE NOTICE '1 in session_managed_object_start: %', COALESCE((SELECT json_agg(row_to_json(t)) FROM (SELECT * FROM hive.sessions) t)::text, 'hive.sessions is empty');


    RAISE NOTICE '2 in session_managed_object_start: %', COALESCE((SELECT json_agg(row_to_json(t)) FROM (SELECT * FROM hive.sessions) t)::text, 'hive.sessions is empty');

    RAISE NOTICE 'Executing reconnect function for session: %', _session_name;

    RAISE NOTICE 'reconnect string is %', __reconnect_string;
    EXECUTE __reconnect_string INTO __session_handle; -- mtlk security issue ?
    RAISE NOTICE 'Reconnect function execution completed for session: %. Returned value: %', _session_name, __session_handle;

    -- update the session_handle field in the params column
    UPDATE hive.sessions
    SET session_handle = __session_handle
    WHERE name = _session_name;

    RAISE NOTICE 'Updated session_handle for session: % after reconnect function execution', _session_name;
END;
$$
;


CREATE OR REPLACE FUNCTION hive.session_get_managed_object_handle(IN _session_name TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS
$$
DECLARE
    __session_ptr BIGINT;
BEGIN
    __session_ptr  = (SELECT session_handle FROM hive.sessions WHERE name = _session_name);
    return __session_ptr;
END;
$$
;


CREATE OR REPLACE FUNCTION hive.session_managed_object_stop(_session_name TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
DECLARE
  __session RECORD;
  __func_to_exec TEXT;
  __session_handle_param TEXT;
BEGIN

  __session = (SELECT *  FROM hive.sessions WHERE name = _session_name LIMIT 1) ;

    __func_to_exec := __session.disconnect_function;
    __session_handle_param := __session.session_handle;

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
END;
$$
;


CREATE OR REPLACE FUNCTION hive.session_reconnect_all()
RETURNS VOID
LANGUAGE plpgsql
AS
$$
DECLARE
  __session RECORD;
  __reconnect_string TEXT;
  __session_handle BIGINT;
BEGIN
  FOR __session IN SELECT * FROM hive.sessions
  LOOP
    __reconnect_string := __session.reconnect_string;

    RAISE NOTICE 'Executing reconnect function for session: %', __session.name;

    RAISE NOTICE 'reconnect string is %', __reconnect_string;
    EXECUTE __reconnect_string INTO __session_handle; -- mtlk security issue ?
    RAISE NOTICE 'Reconnect function execution completed for session: %. Returned value: %', __session.name, __session_handle;

    -- update the session_handle field in the params column
    UPDATE hive.sessions
    SET session_handle = __session_handle
    WHERE name = __session.name;

    RAISE NOTICE 'Updated session_handle for session: % after reconnect function execution', __session.name;
  END LOOP;
END;
$$
;


CREATE OR REPLACE FUNCTION hive.session_disconnect_all()
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
    FOR __session IN SELECT * FROM hive.sessions LOOP
        __func_to_exec := __session.disconnect_function;
        __session_handle_param := __session.session_handle;

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
