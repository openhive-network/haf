
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    UPDATE hive.irreversible_data SET is_dirty = FALSE;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.set_irreversible_dirty();
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT( SELECT is_dirty FROM hive.irreversible_data ) = TRUE, 'Irreversible data are not dirty';
    ASSERT( SELECT * FROM hive.is_irreversible_dirty() ) = TRUE, 'hive.is_irreversible_dirty returns FALSE';
END
$BODY$
;




