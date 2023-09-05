CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.disable_fk_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM hive.disable_indexes_of_irreversible();
    PERFORM hive.enable_indexes_of_irreversible();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT hive.are_indexes_dropped() ) = FALSE, 'Indexes are disabled';
END;
$BODY$
;
