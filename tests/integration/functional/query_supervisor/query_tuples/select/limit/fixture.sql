ALTER SYSTEM SET session_preload_libraries TO 'libquery_supervisor.so';

DO
$BODY$
BEGIN
    EXECUTE format( 'ALTER ROLE haf_admin IN DATABASE %s SET query_supervisor.limits_enabled TO true'
        , current_database()
        );
    EXECUTE format( 'ALTER ROLE alice IN DATABASE %s SET query_supervisor.limits_enabled TO true'
        , current_database()
        );
END;
$BODY$
;

SELECT pg_reload_conf();