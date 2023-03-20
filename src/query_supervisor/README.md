# QUERY SUPERVISOR

A Postgres module which limits execution of queries

## Installation
The module needs to be installed in a Postgres PKGLIBRARY directory ( `pg_config --pkglibrary` )

The best option is to execute  'sudo ninja install' from cmake build directory.

Preferred method of loading the module is set `session_preload_libraries` postgres configuration option:  
`session_preload_libraries='libquery_supervisor.so'`

The option cannot be overridden by non-superusers, and guarantees that each user's connection backend process
will start with loaded 'query_supervisor'.

## Configuration
The module adds new configuration option:

1. `query_supervisor.limited_users` option is a string with list of users names whose queries are limited by the module. Option can be set only by superuser or with `postgresql.conf` file.