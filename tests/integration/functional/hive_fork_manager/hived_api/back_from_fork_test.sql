DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- GOT PREPARED DATA SCHEMA
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
    PERFORM hive.back_from_fork( 10 );
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
    ASSERT EXISTS ( SELECT FROM hive.events_queue WHERE event = 'BACK_FROM_FORK' AND block_num = 2 ), 'No event added'; -- block num is a fork id
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 2, 'Unexpected number of events';
    ASSERT ( SELECT COUNT(*) FROM hive.get_hive_foorks() WHERE block_num = 10 ) = 1, 'No fork added';
    ASSERT ( SELECT COUNT(*) FROM hive.get_hive_foorks() ) = 2, 'To much forks';
END
$BODY$
;




