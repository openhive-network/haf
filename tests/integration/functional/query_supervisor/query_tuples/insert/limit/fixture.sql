ALTER SYSTEM SET session_preload_libraries TO 'libquery_supervisor.so';

DO
$BODY$
BEGIN
    -- We use generate_series to prepare tables for updates
    -- so we need to change limits to select and total tuples number
    -- otherwise query_supervisor will break generate_series
    EXECUTE format( 'ALTER ROLE haf_admin IN DATABASE %s SET query_supervisor.limits_enabled TO true'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE alice IN DATABASE %s SET query_supervisor.limits_enabled TO true'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE haf_admin IN DATABASE %s SET query_supervisor.limit_tuples TO 100000'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE alice IN DATABASE %s SET query_supervisor.limit_tuples TO 100000'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE bob IN DATABASE %s SET query_supervisor.limit_tuples TO 100000'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE haf_admin IN DATABASE %s SET query_supervisor.limit_selects TO 100000'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE alice IN DATABASE %s SET query_supervisor.limit_selects TO 100000'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE bob IN DATABASE %s SET query_supervisor.limit_selects TO 100000'
        , current_database()
        );
END;
$BODY$
;

SELECT pg_reload_conf();