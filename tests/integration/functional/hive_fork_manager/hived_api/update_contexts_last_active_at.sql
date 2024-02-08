CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'alice' );
    PERFORM hive.app_create_context( 'bob' );
    PERFORM hive.app_create_context( 'bob_detached' );
    CALL hive.appproc_context_detach( 'bob_detached' );

    UPDATE hive.contexts hc
    SET last_active_at = '2020-02-02 02:02:02'::TIMESTAMP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
   CALL hive.proc_update_contexts_last_active_at();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    _time_pattern TIMESTAMP := '2020-02-02 02:02:02'::TIMESTAMP;
BEGIN
    ASSERT ( SELECT last_active_at FROM hive.contexts WHERE name='alice' ) != _time_pattern, 'Alice time not changed';
    ASSERT ( SELECT last_active_at FROM hive.contexts WHERE name='bob' ) != _time_pattern, 'Bobs time not changed';
    ASSERT ( SELECT last_active_at FROM hive.contexts WHERE name='bob_detached' ) = _time_pattern, 'Bobs detached time changed';
END;
$BODY$
;