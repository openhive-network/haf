CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __limited BOOLEAN;
BEGIN
    SHOW query_supervisor.limits_enabled INTO __limited;
    ASSERT __limited = false, 'haf_admin is limited';
    PERFORM pg_sleep( 5 );
END
$BODY$
;





