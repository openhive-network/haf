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
BEGIN
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
END;
$$
;
