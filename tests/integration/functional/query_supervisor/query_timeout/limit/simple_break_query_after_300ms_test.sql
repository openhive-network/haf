CREATE OR REPLACE PROCEDURE alice_test_error()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM pg_sleep( 5 );
END
$BODY$
;





