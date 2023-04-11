DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    UPDATE hive.irreversible_data SET is_dirty = FALSE;
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.set_irreversible_dirty();
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT( SELECT is_dirty FROM hive.irreversible_data ) = TRUE, 'Irreversible data are not dirty';
    ASSERT( SELECT * FROM hive.is_irreversible_dirty() ) = TRUE, 'hive.is_irreversible_dirty returns FALSE';
END
$BODY$
;




