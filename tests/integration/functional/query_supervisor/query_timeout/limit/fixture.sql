--ALTER ROLE haf_admin SET local_preload_libraries TO 'query_supervisor.so';
--ALTER ROLE alice SET local_preload_libraries TO 'query_supervisor.so';
SELECT pg_reload_conf();