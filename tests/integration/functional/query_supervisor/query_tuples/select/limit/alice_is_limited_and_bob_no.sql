CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM * FROM generate_series(1,10000);
END;
$BODY$
;


CREATE OR REPLACE PROCEDURE bob_test_when()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    PERFORM * FROM generate_series(1,10000);
END;
$BODY$
;

