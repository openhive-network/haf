
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    CREATE TABLE test_table( A INTEGER, B INTEGER );

    INSERT INTO test_table( A, B )
    SELECT GENERATE_SERIES, GENERATE_SERIES % 5
    FROM GENERATE_SERIES(1, 100000);

    EXECUTE  format( 'ALTER ROLE SESSION_USER IN DATABASE %s SET query_supervisor.limits_enabled TO true'
        , current_database()
    );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_error()
        LANGUAGE 'plpgsql'
    AS
$BODY$
BEGIN
    SET max_parallel_workers_per_gather = 4;
    SET max_parallel_workers = 8;
    SET max_parallel_maintenance_workers = 16;
    SET parallel_setup_cost = 0;
    SET parallel_tuple_cost = 0;
    SET force_parallel_mode = true;
    SET min_parallel_table_scan_size = 0;

    PERFORM A, B FROM  test_table WHERE A < 200000 and B < 4;
    -- query supervisor breaks the query above but after consolidation of tuples from bg workers
    -- each gb worker consumes more tuples than the limit ( 1000 )
END
$BODY$
;