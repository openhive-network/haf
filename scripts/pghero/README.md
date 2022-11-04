### Pghero monitoring

You need to enable
[pg_stat_statements](https://www.postgresql.org/docs/13/pgstatstatements.html)
extension by setting something like this in `postgresql.conf` file for
postgresql server to be monitored:
```conf
shared_preload_libraries = pg_stat_statements
track_functions = pl
track_io_timing = on
track_activity_query_size = 2048
pg_stat_statements.track = all
```
Restart postgresql server to make above settings alive.

Setup password for user `pghero` in environment – in `.env` file or by
running something like this in terminal
```bash
 export BLOCKTRADES_PGHERO_PGHERO_USER_PASSWORD=<secret-password>
 export BLOCKTRADES_PGHERO_DATABASE_URL=postgres://pghero:${BLOCKTRADES_PGHERO_PGHERO_USER_PASSWORD}@<PGHOST>:5432/pghero
```
Replace `<secret-password>` with your password. Replace `<PGHOST>` with
host to be monitored.

Run scripts

- blocktrades/pghero/setup/21_create_role_pghero.sql
- blocktrades/pghero/setup/22-pghero-set-password.sh
- blocktrades/pghero/setup/31_setup_monitoring_pghero.sql

against database to be monitored. You can find example run commands at
the top of these files. Other scripts in `blocktrades/pghero/setup`
directory are for having historical data in pghero, and we usually don't
need this functionality.

Start `blocktrades/pghero` service, bind mounting yaml file with
following example contents:
```yaml
databases:
  my-monitored-db:
    url: <%= ENV["DATABASE_URL"] %>/<my-monitored-db>
```
to the location `/app/config/pghero.yml` in docker container.


```
docker exec -u root haf-instance-5M ./haf/scripts/pghero/setup_pghero.sh --database=haf_block_log
```
