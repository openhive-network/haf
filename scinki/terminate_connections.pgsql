SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'psql_tools_test_db ';
drop database psql_tools_test_db ;