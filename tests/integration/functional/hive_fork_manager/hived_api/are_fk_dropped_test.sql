CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
    PERFORM hive.enable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.are_fk_dropped() ) = FALSE, 'Foreign keys are disabled';
END;
$BODY$
;
