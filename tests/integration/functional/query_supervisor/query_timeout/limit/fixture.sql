ALTER SYSTEM SET query_supervisor.limited_users TO haf_admin;
SELECT pg_reload_conf();