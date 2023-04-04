ALTER SYSTEM SET session_preload_libraries TO 'libquery_supervisor.so';
SELECT pg_reload_conf();