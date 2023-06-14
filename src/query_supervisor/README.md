# QUERY SUPERVISOR

Query Supervisor is a Postgres module that limits the execution of queries for specified users.

## Installation
To install the module, it must be placed in the Postgres PKGLIBRARY directory (`pg_config --pkglibrary`).

The recommended installation method is to execute `sudo ninja install` from the cmake build directory.

The preferred way to load the module is to set the session_preload_libraries configuration option in Postgres:
```session_preload_libraries='libquery_supervisor.so'```

This option cannot be overridden by non-superusers and ensures that the module is loaded for each user's connection backend process.

## Configuration
The module introduces the following configuration options:

1. `query_supervisor.limits_enabled` A boolean value which enables  limits for roles. Option van be set only by a superuser.
2. `query_supervisor.limit_tuples` A positive integer that limits the number of tuples processed by a query. The default value is 1000. This option can only be set by a superuser or in the postgresql.conf file. Changing this parameter will affect all new and currently open sessions and their newly created queries.
3. `query_supervisor.limit_updates` A positive integer that limits the number of tuples updated by a query. The default value is 1000. This option can only be set by a superuser or in the postgresql.conf file. Changing this parameter will affect all new and currently open sessions and their newly created queries.
4. `query_supervisor.limit_inserts` A positive integer that limits the number of tuples inserted by a query. The default value is 1000. This option can only be set by a superuser or in the postgresql.conf file. Changing this parameter will affect all new and currently open sessions and their newly created queries.
5. `query_supervisor.limit_deletes` A positive integer that limits the number of tuples deleted by a query. The default value is 1000. This option can only be set by a superuser or in the postgresql.conf file. Changing this parameter will affect all new and currently open sessions and their newly created queries.
6`query_supervisor.limit_timeout` A positive integer that limits the duration of queries executed by the limited users, in milliseconds. The default value is 300. This option can only be set by a superuser or in the postgresql.conf file. Changing this parameter will affect all new and currently open sessions and their newly created queries.

## Known problems
1. When running a query with parallel background workers (known as parallel query), it is possible for each worker to surpass the tuple limit. Nevertheless, the backend process will ensure that the query is ultimately terminated.
2. Limit for deletes does not work when TRUNCATE command is used.
