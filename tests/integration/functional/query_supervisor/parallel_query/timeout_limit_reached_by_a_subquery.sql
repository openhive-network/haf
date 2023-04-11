DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    CREATE TABLE test_table( A INTEGER, B INTEGER );

    INSERT INTO test_table( A, B )
    SELECT GENERATE_SERIES, GENERATE_SERIES % 5
    FROM GENERATE_SERIES(1, 10000000);

    EXECUTE  format( 'ALTER ROLE SESSION_USER IN DATABASE %s SET query_supervisor.limited_users TO ''%s'''
        , current_database()
        , current_user
     );

    -- ensures that a query will not reach tuples limit
    EXECUTE  format( 'ALTER ROLE SESSION_USER IN DATABASE %s SET query_supervisor.limit_tuples TO 90000000'
        , current_database()
    );
END
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_error;
CREATE FUNCTION haf_admin_test_error()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
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

    PERFORM A, B FROM  test_table WHERE A < 20000000 and B < 4;
END
$BODY$
;