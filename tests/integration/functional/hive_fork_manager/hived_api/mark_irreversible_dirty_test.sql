DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    IF select count(*) from hive.irreversible_data = 0 THEN
        raise NOTICE 'MTTK INSERT INTO hive.irreversible_data Values(1, null, FALSE)';
        INSERT INTO hive.irreversible_data Values(1, null, FALSE);
    END IF;
    UPDATE hive.irreversible_data SET is_dirty = FALSE;
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
    ASSERT( SELECT is_dirty FROM hive.irreversible_data ) = TRUE, 'Irreversible data are not dirty';
    ASSERT( SELECT * FROM hive.is_irreversible_dirty() ) = TRUE, 'hive.is_irreversible_dirty returns FALSE';
END
$BODY$
;




