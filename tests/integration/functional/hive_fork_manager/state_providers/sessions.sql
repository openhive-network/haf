CREATE TABLE IF NOT EXISTS hive.memory_between_procedures (
    pid integer,
    session_ptr BIGINT
);



DROP PROCEDURE IF EXISTS haf_admin_procedure_test_given;
CREATE PROCEDURE haf_admin_procedure_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
    __reconnect_string TEXT;
    __disconnect_function TEXT;
BEGIN
    --__session_ptr = (SELECT hive.test_in_c_create_a_structure('auto', 'matics'));
    __reconnect_string = format('SELECT hive.test_in_c_create_a_structure(%L, %L)', 'auto', 'matics');
    __disconnect_function = 'SELECT hive.test_in_c_destroy(%s)';


    PERFORM hive.setup_session(
        'context', 
        jsonb_build_object(       
            'reconnect_string', __reconnect_string,
            'disconnect_function', __disconnect_function,
            'session_handle', __session_ptr
        )
    );

    --PERFORM hive.session_reconnect('context');
    PERFORM hive.sessions_reconnect();

    --inside the same process:
    
    __session_ptr = hive.get_session_ptr('context') ;

    RAISE NOTICE 'returned %', (SELECT hive.test_in_c_get_strings_sum(__session_ptr));
    ASSERT 'automatics' = (SELECT hive.test_in_c_get_strings_sum(__session_ptr));

    PERFORM hive.test_in_c_destroy(__session_ptr);

    -- ASSERT 'context; not in sessions

    __session_ptr = (SELECT hive.test_in_c_create_a_structure('auto', 'moto'));

    ASSERT __session_ptr = hive.get_session_ptr('context') ;


    --disconnect sessions because we are leaving the current process
    PERFORM hive.sessions_disconnect();

    RAISE NOTICE 'Current backend PID is: %', pg_backend_pid();

    INSERT INTO hive.memory_between_procedures (pid, session_ptr)
    VALUES (pg_backend_pid(), __session_ptr);



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

    ASSERT(pg_backend_pid() <> previous_pid);
    PERFORM hive.sessions_reconnect();


    __session_ptr = hive.get_session_ptr('context');
    ASSERT(__session_ptr <> prevoius_session_ptr);

    RAISE NOTICE 'returned %', (SELECT hive.test_in_c_get_strings_sum(__session_ptr));


    PERFORM hive.sessions_disconnect();
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
    PERFORM hive.sessions_reconnect();
    __session_ptr = hive.get_session_ptr('context');
    PERFORM hive.test_in_c_destroy(__session_ptr);

END;
$BODY$
;

