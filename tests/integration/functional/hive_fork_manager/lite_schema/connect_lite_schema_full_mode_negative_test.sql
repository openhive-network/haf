
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Enable lite schema on fresh DB
    PERFORM hive.connect( 'test', 0, 0, 0, TRUE, TRUE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Should fail: cannot run full mode on lite-schema DB
    PERFORM hive.connect( 'test2', 0, 0, 0, FALSE, FALSE );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.is_lite_schema(), 'lite_schema flag should still be set';
END;
$BODY$
;
