
DROP PROCEDURE IF EXISTS haf_admin_procedure_test_given;
CREATE PROCEDURE haf_admin_procedure_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
BEGIN
    --disconnect sessions because we are leaving the current process
    PERFORM hive.sessions_disconnect();

END;
$BODY$
;


DROP PROCEDURE IF EXISTS haf_admin_procedure_test_when;
CREATE PROCEDURE haf_admin_procedure_test_when()
AS
$BODY$
DECLARE
    __session_ptr BIGINT;
BEGIN

    -- PERFORM hive.sessions_reconnect();
    -- __session_ptr = hive.get_session_ptr('context');

    -- ASSERT 1 = (SELECT * FROM hive.consensus_state_provider_get_expected_block_num(__session_ptr)),
    --                          'consensus_state_provider_get_expected_block_num should return 1';

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
    rec RECORD;
    __session_ptr BIGINT;
BEGIN
    PERFORM hive.sessions_reconnect();
    -- __session_ptr = hive.get_session_ptr('context');

    -- -- After  reconnecting - automatic undo has been performed:
    -- ASSERT 1 = (SELECT * FROM hive.consensus_state_provider_get_expected_block_num(__session_ptr)),
    --                          'consensus_state_provider_get_expected_block_num should return 1';


END;
$BODY$
;

