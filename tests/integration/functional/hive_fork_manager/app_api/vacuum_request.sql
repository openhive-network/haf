CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
    CREATE TABLE A.table2(id  INTEGER ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_impersonal_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.app_request_table_vacuum('a', 'table1');
    PERFORM hive.app_request_table_vacuum('a', 'table1', NULL, 'freeze');
    PERFORM hive.app_request_table_vacuum('a.table2', _kind => 'analyze');
    PERFORM hive.app_request_table_vacuum('a.table2', INTERVAL '1 hour', 'vacuum');
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
   -- a request of one kind does not replace a pending request of another kind
   ASSERT
       (SELECT array_agg(kind ORDER BY kind) FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'table1' AND status = 'requested' )
       = ARRAY['freeze', 'full']
        , 'a.table1 should have pending full (the default kind) and freeze requests';

   ASSERT
       (SELECT array_agg(kind ORDER BY kind) FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'table2' AND status = 'requested' )
       = ARRAY['analyze', 'vacuum']
        , 'a.table2 should have pending analyze and vacuum requests';

   CALL alice_test_min_interval_per_kind();
   CALL alice_test_invalid_kind();
   CALL alice_test_nonexistent_table();
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_min_interval_per_kind()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- as hived leaves a request it has run
    UPDATE hafd.vacuum_requests SET status = 'vacuumed', last_vacuumed_time = NOW()
    WHERE schema_name = 'a' AND table_name = 'table1' AND kind = 'full';
    UPDATE hafd.vacuum_requests SET status = 'vacuumed', last_vacuumed_time = NOW() - INTERVAL '2 hours'
    WHERE schema_name = 'a' AND table_name = 'table1' AND kind = 'freeze';

    PERFORM hive.app_request_table_vacuum('a', 'table1', INTERVAL '1 hour');
    PERFORM hive.app_request_table_vacuum('a', 'table1', INTERVAL '1 hour', 'freeze');
    PERFORM hive.app_request_table_vacuum('a', 'table1', INTERVAL '1 hour', 'analyze');

    ASSERT
        (SELECT status FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'table1' AND kind = 'full') = 'vacuumed'
        , 'a recent full vacuum should throttle a new full request';
    ASSERT
        (SELECT status FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'table1' AND kind = 'freeze') = 'requested'
        , 'a recent full vacuum must not throttle a freeze request';
    ASSERT
        (SELECT status FROM hafd.vacuum_requests WHERE schema_name = 'a' AND table_name = 'table1' AND kind = 'analyze') = 'requested'
        , 'a recent full vacuum must not throttle an analyze request';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE alice_test_invalid_kind()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __requests_before BIGINT;
    __kind TEXT;
    __error_caught BOOLEAN;
BEGIN
    __requests_before := (SELECT COUNT(*) FROM hafd.vacuum_requests);

    FOREACH __kind IN ARRAY ARRAY['FULL', 'cluster', NULL] LOOP
        __error_caught := FALSE;
        BEGIN
            PERFORM hive.app_request_table_vacuum('a', 'table2', NULL, __kind);
        EXCEPTION
            WHEN SQLSTATE '22023' THEN
                __error_caught := TRUE;
        END;
        ASSERT __error_caught, format('vacuum kind %s should be rejected', quote_nullable(__kind));

        __error_caught := FALSE;
        BEGIN
            PERFORM hive.app_request_table_vacuum('a.table2', NULL, __kind);
        EXCEPTION
            WHEN SQLSTATE '22023' THEN
                __error_caught := TRUE;
        END;
        ASSERT __error_caught, format('vacuum kind %s should be rejected by the qualified name form', quote_nullable(__kind));
    END LOOP;

    -- the table is writable by applications, so the kind is checked there too
    __error_caught := FALSE;
    BEGIN
        INSERT INTO hafd.vacuum_requests (schema_name, table_name, kind) VALUES ('a', 'table2', 'cluster');
    EXCEPTION
        WHEN check_violation THEN
            __error_caught := TRUE;
    END;
    ASSERT __error_caught, 'hafd.vacuum_requests should reject an unknown kind';

    ASSERT (SELECT COUNT(*) FROM hafd.vacuum_requests) = __requests_before
        , 'a rejected vacuum kind must not insert a request';
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
