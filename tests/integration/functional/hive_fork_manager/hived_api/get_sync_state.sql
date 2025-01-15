CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    UPDATE hafd.hive_state SET state = 'REINDEX_WAIT';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.get_sync_state() ) = 'REINDEX_WAIT', 'Wrong sync state';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.get_sync_state() ) = 'REINDEX_WAIT', 'Wrong sync state';
END;
$BODY$
;