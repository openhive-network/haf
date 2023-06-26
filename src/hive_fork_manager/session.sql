CREATE OR REPLACE FUNCTION hive.sessions_reconnect()
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN
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
BEGIN
    INSERT INTO hive.sessions(name, params) VALUES (_name, _params);
    RETURN TRUE;
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
