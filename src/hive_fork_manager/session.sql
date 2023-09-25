CREATE OR REPLACE FUNCTION hive.session_setup(IN _session_name TEXT, IN _reconnect_string TEXT, IN _disconnect_function TEXT)
RETURNS void
LANGUAGE plpgsql
AS
$$
BEGIN

    INSERT INTO hive.sessions(name, reconnect_string, disconnect_function) VALUES (_session_name, _reconnect_string, _disconnect_function);

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
    __reconnect_string = (SELECT reconnect_string  FROM hive.sessions     WHERE name = _session_name LIMIT 1) ;
    EXECUTE __reconnect_string INTO __session_handle; -- mtlk security issue ? However there are many places where EXECUTE calls a string.

    -- update the session_handle field in the params column
    UPDATE hive.sessions
    SET session_handle = __session_handle
    WHERE name = _session_name;

END;
$$
;


CREATE OR REPLACE FUNCTION hive.session_get_managed_object_handle(IN _session_name TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN

    RETURN (SELECT session_handle FROM hive.sessions WHERE name = _session_name);

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

  SELECT * INTO __session FROM hive.sessions WHERE name = _session_name LIMIT 1 ;

    __func_to_exec := __session.disconnect_function;
    __session_handle_param := __session.session_handle;

    IF __func_to_exec IS NOT NULL THEN
        EXECUTE format(__func_to_exec, __session_handle_param);
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

    EXECUTE __reconnect_string INTO __session_handle; -- mtlk security issue ?

    -- update the session_handle field in the params column
    UPDATE hive.sessions
    SET session_handle = __session_handle
    WHERE name = __session.name;

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
BEGIN
    FOR __session IN SELECT * FROM hive.sessions LOOP
        __func_to_exec := __session.disconnect_function;
        __session_handle_param := __session.session_handle;


        IF __func_to_exec IS NOT NULL THEN
            EXECUTE format(__func_to_exec, __session_handle_param);
        END IF;
    END LOOP;
END;
$$
;
