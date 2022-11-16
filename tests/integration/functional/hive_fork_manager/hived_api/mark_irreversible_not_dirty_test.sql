DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.force_irr_data_insert();
    UPDATE hive.irreversible_data SET is_dirty = TRUE;
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.set_irreversible_not_dirty();
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT( SELECT is_dirty FROM hive.irreversible_data ) = FALSE, 'Irreversible data are dirty';
    ASSERT( SELECT * FROM hive.is_irreversible_dirty() ) = FALSE, 'hive.is_irreversible_dirty returns TRUE';
END
$BODY$
;




