
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    -- query shall not be broken
    CREATE TABLE numbers( num INT );

    EXECUTE  format( 'ALTER ROLE alice IN DATABASE %s SET query_supervisor.limit_inserts TO ''0'''
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
    INSERT INTO numbers VALUES( 1 );
END
$BODY$
;





