#!/bin/bash
set -euo pipefail

# Paths for the split container layout.
# In the split setup, config and blockchain are mounted separately:
#   - CONFIG_DIR: where config.ini lives (--data-dir for hived)
#   - DATADIR: general data directory (blockchain, logs)
#   - SHM_DIR: shared memory (overridable to ramdisk)
#   - WAL_DIR: hived's psql write-ahead log (overridable)
CONFIG_DIR="${CONFIG_DIR:-/home/hived/config}"
DATADIR="${DATADIR:-/home/hived/datadir}"
SHM_DIR="${SHM_DIR:-/home/hived/shm_dir}"
WAL_DIR="${WAL_DIR:-/home/hived/wal_dir}"
POSTGRES_HOST="${POSTGRES_HOST:-db}"
POSTGRES_DB="${POSTGRES_DB:-haf_block_log}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

echo "Starting hived container (PID $$)"
echo "  POSTGRES_HOST=${POSTGRES_HOST}"
echo "  CONFIG_DIR=${CONFIG_DIR}"
echo "  DATADIR=${DATADIR}"
echo "  SHM_DIR=${SHM_DIR}"
echo "  WAL_DIR=${WAL_DIR}"

# Check if the first argument is an empty string (docker compose artifact)
if [ "$#" -gt 0 ] && [ -z "$1" ]; then
    shift
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}..."
until pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U hived -d "$POSTGRES_DB" -q 2>/dev/null; do
  sleep 2
done
echo "PostgreSQL is ready."

PSQL_URL="dbname=${POSTGRES_DB} host=${POSTGRES_HOST} port=${POSTGRES_PORT} user=hived"

if [ ! -f "$CONFIG_DIR/config.ini" ]; then
  echo "No config file exists, creating a default config file"

  /home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
    --data-dir="${CONFIG_DIR}" --shared-file-dir="${SHM_DIR}" --psql-wal-directory="${WAL_DIR}" \
    --plugin=sql_serializer --psql-url="${PSQL_URL}" \
    "$@" --dump-config > /dev/null 2>&1

  # add a default set of plugins that API nodes should run
  sed -i 's/^# plugin = .*$/plugin = metadata node_status_api account_by_key account_by_key_api block_api condenser_api database_api json_rpc market_history market_history_api network_broadcast_api p2p rc_api state_snapshot transaction_status transaction_status_api wallet_bridge_api webserver/g' "$CONFIG_DIR/config.ini"

  # set default logging config
  sed -i 's|^[# \t]*log-appender = .*$|log-appender = {"appender":"stderr","stream":"std_error","time_format":"iso_8601_microseconds"} {"appender":"p2p","file":"logs/hived/p2p/p2p.log","truncate":false,"time_format":"iso_8601_milliseconds", "rotation_interval": 86400, "rotation_limit": 2592000} {"appender": "default", "file": "logs/hived/default/default.log","truncate":false, "time_format": "iso_8601_milliseconds", "rotation_interval": 86400, "rotation_limit": 2592000}|;s|^[# \t]*log-logger = .*$|log-logger = {"name":"default","level":"info","appenders":["stderr", "default"]} {"name":"user","level":"debug","appenders":["stderr", "default"]} {"name":"p2p","level":"warn","appenders":["p2p"]}|' "$CONFIG_DIR/config.ini"
else
  echo "Using existing config file: $CONFIG_DIR/config.ini"
fi

if [ "$#" -gt 0 ]; then
  echo "Executing hived using additional command line arguments:" "$@"
else
  echo "Executing hived"
fi

exec /home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir="${CONFIG_DIR}" --shared-file-dir="${SHM_DIR}" --psql-wal-directory="${WAL_DIR}" \
  --plugin=sql_serializer --psql-url="${PSQL_URL}" \
  "$@"
