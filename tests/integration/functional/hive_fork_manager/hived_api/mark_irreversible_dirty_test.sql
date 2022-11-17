DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.update_irr_data_dirty(FALSE);
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
    PERFORM hive.set_irreversible_dirty();
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
    ASSERT COALESCE((SELECT is_dirty FROM hive.get_irr_data()), FALSE) = TRUE, 'Irreversible data are not dirty';
    ASSERT( SELECT * FROM hive.is_irreversible_dirty() ) = TRUE, 'hive.is_irreversible_dirty returns FALSE'; 
END
$BODY$
;




