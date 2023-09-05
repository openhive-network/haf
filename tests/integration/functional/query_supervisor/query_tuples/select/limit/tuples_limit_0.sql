
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    EXECUTE  format( 'ALTER ROLE alice IN DATABASE %s SET query_supervisor.limit_tuples TO ''0'''
        , current_database()
    );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM * FROM generate_series(1,1);
END
$BODY$
;





