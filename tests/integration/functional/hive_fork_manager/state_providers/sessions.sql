DROP PROCEDURE IF EXISTS haf_admin_procedure_test_given;
CREATE PROCEDURE haf_admin_procedure_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
    __session_ptr2 BIGINT;
    __reconnect_string TEXT;
    __disconnect_function TEXT;
BEGIN


  -- normal usage in one process

  -- 1. Configure the service
    __reconnect_string = format('SELECT hive.testincstructure_create(%L, %L)', 'auto', 'matics');
    __disconnect_function = 'SELECT hive.testincstructure_destroy(%s)';
    PERFORM hive.session_setup('context', __reconnect_string, __disconnect_function);

  -- 2. Start the service
    PERFORM hive.session_managed_object_start('context');

  -- 3. Peform service specific operations
    __session_ptr = hive.session_get_managed_object_handle('context') ;
    ASSERT 'automatics' = (SELECT hive.testincstructure_sum(__session_ptr)), 'A0';

  -- 4. Stop the service (destroying underlying objects in memory)
    PERFORM hive.session_managed_object_stop('context');

  -- 5. Unlink the service
    PERFORM hive.session_forget('context');


    -- -- __session_ptr = hive.session_get_managed_object_handle('context') ;
    -- -- ASSERT 'automatics' = (SELECT hive.testincstructure_sum(__session_ptr)), 'A1';
    -- -- -- ASSERT 'context; not in sessions
    -- -- __session_ptr = (SELECT hive.testincstructure_create('auto', 'moto'));
    -- -- __session_ptr2 =  hive.session_get_managed_object_handle('context');
    -- -- --ASSERT __session_ptr =__session_ptr2, 'A2 __session_ptr=' || __session_ptr || ' __session_ptr2='  || __session_ptr2;


  -- Start it again to test reconnection after changing process
  -- 1. Configure the service
    __reconnect_string = format('SELECT hive.testincstructure_create(%L, %L)', 'auto', 'matics');
    __disconnect_function = 'SELECT hive.testincstructure_destroy(%s)';
    PERFORM hive.session_setup('context', __reconnect_string, __disconnect_function);

  -- 2. Start the service
    PERFORM hive.session_managed_object_start('context');

  -- 3. Save session and pid for later comparison
    __session_ptr = hive.session_get_managed_object_handle('context') ;
    INSERT INTO hive.memory_between_procedures (pid, session_ptr)
    VALUES (pg_backend_pid(), __session_ptr);
  
  -- 4. disconnect sessions because we are leaving the current process
    PERFORM hive.session_disconnect_all();

END;
$BODY$
;


DROP PROCEDURE IF EXISTS haf_admin_procedure_test_when;
CREATE PROCEDURE haf_admin_procedure_test_when()
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
    previous_pid INTEGER;
    prevoius_session_ptr BIGINT;
BEGIN
    -- ASSERT -- different getpid
    SELECT pid, session_ptr INTO previous_pid, prevoius_session_ptr FROM hive.memory_between_procedures;


    ASSERT(pg_backend_pid() <> previous_pid), 'Consecutive psql calls should run in different processes';

    -- 1. Restore service after changing process
    PERFORM hive.session_reconnect_all();

    -- 2. restored underlying object has different pointer in this new process
    __session_ptr = hive.session_get_managed_object_handle('context');
    Raise Notice '__session_ptr=%', __session_ptr;
    ASSERT __session_ptr <> prevoius_session_ptr, 'A4 ' || '__session_ptr=' || __session_ptr  || ' prevoius_session_ptr=' || prevoius_session_ptr  ;

    -- 3. Normal stopping before the process exit
    PERFORM hive.session_disconnect_all();

  RAISE NOTICE 'B6';

END;
$BODY$
LANGUAGE 'plpgsql';


DROP PROCEDURE IF EXISTS haf_admin_procedure_test_then;
CREATE PROCEDURE haf_admin_procedure_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
BEGIN
    -- Just dismissing the service
    PERFORM hive.session_forget('context');
END;
$BODY$
;


CREATE TABLE IF NOT EXISTS hive.memory_between_procedures (
    pid integer,
    session_ptr BIGINT
);



DROP TABLE IF EXISTS hive.test_struct;
CREATE TABLE IF NOT EXISTS hive.test_struct(
  str1 TEXT,
  str2 TEXT,
  handle BIGINT);

-- noise
INSERT INTO hive.test_struct VALUES ('bob', 'alice', 1010101);
INSERT INTO hive.test_struct VALUES ('john', 'doe', 102);
INSERT INTO hive.test_struct VALUES ('jane', 'smith', 103);
INSERT INTO hive.test_struct VALUES ('mary', 'johnson', 104);




-- For functional hive.sessions test
-- We are emulating allocatin a two string structure with a pointer
CREATE OR REPLACE FUNCTION hive.testincstructure_create(IN s1 TEXT, IN s2 TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  handle BIGINT;
BEGIN
  handle = (SELECT floor(random() * 9223372036854775807)::BIGINT) ;

  INSERT INTO hive.test_struct VALUES (s1, s2, handle);

  RETURN handle;
END
$$;


CREATE OR REPLACE FUNCTION hive.testincstructure_sum(IN _session_ptr BIGINT)
RETURNS TEXT 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN (SELECT str1 || str2 FROM hive.test_struct WHERE handle = _session_ptr);
END
$$;




CREATE OR REPLACE FUNCTION hive.testincstructure_destroy(IN _session_ptr BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM hive.test_struct WHERE handle = _session_ptr;
END
$$;


