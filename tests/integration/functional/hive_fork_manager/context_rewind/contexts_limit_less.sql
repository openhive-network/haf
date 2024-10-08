CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$

BEGIN
    CREATE SCHEMA A;
    PERFORM hive.context_create( 'context_' || gen.*, 'a' ) FROM generate_series(1, 999) as gen;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive_data.contexts ) = 999, 'Wrong number of contexts !=999';
END
$BODY$
;