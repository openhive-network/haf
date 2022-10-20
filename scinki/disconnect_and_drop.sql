SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'psql_tools_test_db'
  AND pid <> pg_backend_pid();


DROP DATABASE 'psql_tools_test_db';


sudo -u postgres psql -U postgres -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'psql_tools_test_db';"

