ALTER SYSTEM SET query_supervisor.limited_users TO 'alice';
SELECT pg_reload_conf();