DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    ;

    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.app_create_context( 'context_non_forking' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
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
    -- NOTHING TO DO HERE
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'Some block range is returned for inconsistence data - forking';

    SELECT * FROM hive.app_next_block( 'context_non_forking' ) INTO __blocks;
    ASSERT __blocks IS NULL, 'Some block range is returned for inconsistence data - non forking';
END
$BODY$
;




