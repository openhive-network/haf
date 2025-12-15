CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_request_table_vacuum('a', 'table1');
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
   ASSERT
       (SELECT COUNT(*) FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'table1' ) = 1
        , 'a.table1 wrong number of requests';

   ASSERT
       (SELECT status FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'table1' ) = 'requested'
       , 'a.table1 status != requested';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_nonexistent_table()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __error_caught BOOLEAN := FALSE;
    __error_message TEXT;
BEGIN
    -- Try to request vacuum on non-existent table
    BEGIN
        PERFORM hive.app_request_table_vacuum('a', 'nonexistent_table');

        -- If we get here, validation failed
        RAISE EXCEPTION 'Expected exception for non-existent table but none was raised';
    EXCEPTION
        WHEN SQLSTATE '42P01' THEN
            __error_caught := TRUE;
            __error_message := SQLERRM;
            RAISE NOTICE 'Correctly caught exception for non-existent table: %', __error_message;
    END;

    ASSERT __error_caught,
        'Should raise exception when requesting vacuum on non-existent table';

    -- Verify no request was created for the non-existent table
    ASSERT (SELECT COUNT(*) FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'nonexistent_table') = 0,
        'No vacuum request should be created for non-existent table';

    RAISE NOTICE 'Test passed: non-existent table correctly rejected';
END;
$BODY$
;
