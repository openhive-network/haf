CREATE OR REPLACE PROCEDURE test_hived_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.set_sync_state( 'REINDEX_WAIT' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Alice has no access to set state
    PERFORM hive.set_sync_state( 'REINDEX_WAIT' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE test_hived_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT state FROM hafd.hive_state ) = 'REINDEX_WAIT', 'Wrong sync state';
END;
$BODY$
;