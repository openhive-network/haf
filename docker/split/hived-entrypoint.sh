#!/bin/bash
set -euo pipefail

DATADIR="${DATADIR:-/home/hived/datadir}"
SHM_DIR="${SHM_DIR:-${DATADIR}/blockchain}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-haf_block_log}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

echo "Starting hived container (PID $$)"
echo "  POSTGRES_HOST=${POSTGRES_HOST}"
echo "  POSTGRES_DB=${POSTGRES_DB}"
echo "  DATADIR=${DATADIR}"

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

if [ ! -f "$DATADIR/config.ini" ]; then
  echo "No config file exists, creating a default config file"

  /home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
    --data-dir="${DATADIR}" --shared-file-dir="${SHM_DIR}" \
    --plugin=sql_serializer --psql-url="${PSQL_URL}" \
    "$@" --dump-config > /dev/null 2>&1

  # add a default set of plugins that API nodes should run
  sed -i 's/^# plugin = .*$/plugin = metadata node_status_api account_by_key account_by_key_api block_api condenser_api database_api json_rpc market_history market_history_api network_broadcast_api p2p rc_api state_snapshot transaction_status transaction_status_api wallet_bridge_api webserver/g' "$DATADIR/config.ini"

  # set default logging config
  sed -i 's|^[# \t]*log-appender = .*$|log-appender = {"appender":"stderr","stream":"std_error","time_format":"iso_8601_microseconds"} {"appender":"p2p","file":"logs/hived/p2p/p2p.log","truncate":false,"time_format":"iso_8601_milliseconds", "rotation_interval": 86400, "rotation_limit": 2592000} {"appender": "default", "file": "logs/hived/default/default.log","truncate":false, "time_format": "iso_8601_milliseconds", "rotation_interval": 86400, "rotation_limit": 2592000}|;s|^[# \t]*log-logger = .*$|log-logger = {"name":"default","level":"info","appenders":["stderr", "default"]} {"name":"user","level":"debug","appenders":["stderr", "default"]} {"name":"p2p","level":"warn","appenders":["p2p"]}|' "$DATADIR/config.ini"
else
  echo "Using existing config file: $DATADIR/config.ini"
fi

if [ "$#" -gt 0 ]; then
  echo "Executing hived using additional command line arguments:" "$@"
else
  echo "Executing hived"
fi

exec /home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir="${DATADIR}" --shared-file-dir="${SHM_DIR}" \
  --plugin=sql_serializer --psql-url="${PSQL_URL}" \
  "$@"
