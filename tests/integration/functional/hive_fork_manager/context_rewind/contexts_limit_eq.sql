CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$

BEGIN
    PERFORM hive.context_create( 'context_' || gen.* ) FROM generate_series(1, 1000) as gen;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.contexts ) = 1000, 'Wrong number of contexts !=1000';
END
$BODY$
;