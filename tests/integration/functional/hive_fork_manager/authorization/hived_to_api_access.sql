DROP FUNCTION IF EXISTS hived_test_given;
CREATE FUNCTION hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS HIVED
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_when;
CREATE FUNCTION hived_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS HIVED
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_then;
CREATE FUNCTION hived_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.disable_indexes_of_irreversible();
    PERFORM hive.enable_indexes_of_irreversible();
    PERFORM hive.disable_indexes_of_reversible();
    PERFORM hive.enable_indexes_of_reversible();
    PERFORM hive.connect( 'sha', 0 );
    PERFORM hive.set_irreversible_dirty();
    PERFORM hive.set_irreversible_not_dirty();
    PERFORM hive.is_irreversible_dirty();
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_when;
CREATE FUNCTION alice_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_then;
CREATE FUNCTION alice_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_when;
CREATE FUNCTION bob_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_then;
CREATE FUNCTION bob_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS BOB
END;
$BODY$
;
