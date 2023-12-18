CREATE OR REPLACE FUNCTION hive.session_setup(IN _session_name TEXT, IN _reconnect_command TEXT, IN _disconnect_command TEXT)
RETURNS void
LANGUAGE plpgsql
AS
$$
BEGIN

    INSERT INTO hive.sessions(name, reconnect_command, disconnect_command) VALUES (_session_name, _reconnect_command, _disconnect_command);

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
  __reconnect_command TEXT;
  __managed_object_ptr BIGINT;
BEGIN

     __reconnect_command = (SELECT  reconnect_command  FROM hive.sessions     WHERE name = _session_name LIMIT 1) ;
    EXECUTE __reconnect_command INTO __managed_object_ptr; -- mtlk security issue ? However there are many places where EXECUTE calls a string.

    UPDATE hive.sessions
    SET managed_object_ptr = __managed_object_ptr
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

    RETURN (SELECT managed_object_ptr FROM hive.sessions WHERE name = _session_name);

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
  __managed_object_ptr_param TEXT;
BEGIN

    SELECT * INTO __session FROM hive.sessions WHERE name = _session_name LIMIT 1 ;

    __func_to_exec := __session.disconnect_command;
    __managed_object_ptr_param := __session.managed_object_ptr;

    IF __func_to_exec IS NOT NULL THEN
        EXECUTE format(__func_to_exec, __managed_object_ptr_param);
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
  __reconnect_command TEXT;
  __managed_object_ptr BIGINT;
BEGIN
  FOR __session IN SELECT * FROM hive.sessions
  LOOP

    PERFORM hive.session_managed_object_start(__session.name);

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
    __managed_object_ptr_param BIGINT;
BEGIN
    FOR __session IN SELECT * FROM hive.sessions LOOP
        __func_to_exec := __session.disconnect_command;
        __managed_object_ptr_param := __session.managed_object_ptr;

        IF __func_to_exec IS NOT NULL THEN
            EXECUTE format(__func_to_exec, __managed_object_ptr_param);
        END IF;

    END LOOP;
END;
$$
;
