#!/usr/bin/env bash
set -Eeo pipefail

# HAF PostgreSQL container entrypoint.
# Handles database initialization on first boot and extension updates on restart.
#
# On first boot (empty PGDATA):
#   1. Run initdb to initialize the cluster
#   2. Start a temporary postgres server
#   3. Run docker-entrypoint-initdb.d/* scripts (create DB, roles, extension)
#   4. Stop and restart temp server (to pick up shared_preload_libraries from conf.d)
#   5. Run docker-entrypoint-always-initdb.d/* scripts (pg_cron, cron jobs)
#   6. Stop temporary server
#   7. Start postgres normally
#
# On subsequent boots (existing PGDATA):
#   1. Start a temporary postgres server
#   2. Run docker-entrypoint-always-initdb.d/* scripts (pg_hba, extension update, cron)
#   3. Stop temporary server
#   4. Start postgres normally

POSTGRES_VERSION="${POSTGRES_VERSION:-18}"
PGDATA="${PGDATA:-/var/lib/postgresql/${POSTGRES_VERSION}/haf}"
export PGDATA
export PATH="/usr/lib/postgresql/${POSTGRES_VERSION}/bin:$PATH"

# Process init files: .sh files are sourced/executed, .sql files are run via psql
docker_process_init_files() {
  for f in "$@"; do
    case "$f" in
      *.sh)
        if [ -x "$f" ]; then
          echo "  Running $f"
          "$f"
        else
          echo "  Sourcing $f"
          . "$f"
        fi
        ;;
      *.sql)
        echo "  Running $f"
        psql -U postgres -d postgres -f "$f"
        ;;
      *)
        echo "  Ignoring $f (not .sh or .sql)"
        ;;
    esac
  done
}

# Start a temporary postgres server for initialization (not accepting external connections)
docker_temp_server_start() {
  pg_ctl -D "$PGDATA" -o "-c listen_addresses='' -p 5432" -w start
}

# Stop the temporary postgres server
docker_temp_server_stop() {
  pg_ctl -D "$PGDATA" -m fast -w stop
}

echo "HAF PostgreSQL container starting..."
echo "  POSTGRES_VERSION=${POSTGRES_VERSION}"
echo "  PGDATA=${PGDATA}"

# Ensure PGDATA parent directory exists and has correct permissions
mkdir -p "$(dirname "$PGDATA")"
chown postgres:postgres "$(dirname "$PGDATA")"

# Ensure tablespace directory exists
TABLESPACE_DIR="${HAF_TABLESPACE_DIR:-/var/lib/postgresql/tablespace}"
mkdir -p "$TABLESPACE_DIR"
chown postgres:postgres "$TABLESPACE_DIR"

# Ensure config directories exist
mkdir -p /etc/postgresql/conf.d
mkdir -p /etc/postgresql/custom.conf.d

# Switch to postgres user for all database operations
if [ "$(id -u)" = '0' ]; then
  exec gosu postgres "$BASH_SOURCE" "$@"
fi

DATABASE_ALREADY_EXISTS=
if [ -s "$PGDATA/PG_VERSION" ]; then
  DATABASE_ALREADY_EXISTS='true'
fi

if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
  echo "=== First boot: initializing database cluster ==="

  # Initialize the cluster in a temp directory (initdb refuses non-empty dirs)
  INITDB_TMPDIR=$(mktemp -d /tmp/initdb.XXXXXX)
  initdb -D "$INITDB_TMPDIR"

  # Move initialized files to PGDATA
  mkdir -p "$PGDATA"
  cd "$INITDB_TMPDIR" && tar cf - . | (cd "$PGDATA" && tar xf -)
  rm -rf "$INITDB_TMPDIR"

  docker_temp_server_start

  echo "=== Running first-boot initialization scripts ==="
  if [ -d /docker-entrypoint-initdb.d ]; then
    docker_process_init_files /docker-entrypoint-initdb.d/*
  fi

  # Restart the temp server to pick up shared_preload_libraries added by
  # 005-update-postgresql-conf.sh (pg_cron, pg_stat_statements via conf.d).
  # Without this restart, CREATE EXTENSION pg_cron fails because the pg_cron
  # shared library isn't loaded yet.
  docker_temp_server_stop
  docker_temp_server_start

  echo "=== Running always-run scripts (first boot) ==="
  if [ -d /docker-entrypoint-always-initdb.d ]; then
    docker_process_init_files /docker-entrypoint-always-initdb.d/*
  fi

  docker_temp_server_stop

  echo "=== First-boot initialization complete ==="
else
  echo "=== Existing database found, running update scripts ==="

  docker_temp_server_start

  if [ -d /docker-entrypoint-always-initdb.d ]; then
    docker_process_init_files /docker-entrypoint-always-initdb.d/*
  fi

  docker_temp_server_stop

  echo "=== Update scripts complete ==="
fi

echo "Starting PostgreSQL server..."
exec postgres -D "$PGDATA" "$@"
