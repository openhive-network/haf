
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __value BOOLEAN;
BEGIN
    SELECT setting FROM pg_settings WHERE name='query_supervisor.limits_enabled' INTO __value;

    ASSERT __value IS NOT NULL , 'query_supervisor.limits_enabled does not exist';
    ASSERT __value = false , 'Default value of query_supervisor.limit_enabled is not false';
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __value BOOLEAN;
BEGIN
    SET query_supervisor.limits_enabled TO 'true';
    SELECT setting FROM pg_settings WHERE name='query_supervisor.limits_enabled' INTO __value;

    ASSERT __value = true , 'query_supervisor.limits_enabled != true';
END
$BODY$
;





