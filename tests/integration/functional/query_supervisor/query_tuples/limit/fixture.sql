ALTER SYSTEM SET query_supervisor.limited_users TO 'haf_admin,alice';
SELECT pg_reload_conf();