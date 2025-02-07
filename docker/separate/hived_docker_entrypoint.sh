#! /bin/bash
set -x
set -euo pipefail

eval $(fixuid -q)

DATADIR=/home/hived/datadir
cd ${DATADIR}
exec 1> >(tee -ia docker-entrypoint.log) 2>&1

# Check if the first argument is an empty string.  The structure of haf_api_node's
# compose.yaml files causes it to pass a single argument that's an empty string
# when the user really intends to pass no arguments.  Deal with that here:
if [ "$#" -gt 0 ] && [ -z "$1" ]; then
    shift
fi


if [ ! -f "$DATADIR/config.ini" ]; then
  echo "No config file exists, creating a default config file"

  /usr/local/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
    --data-dir="${DATADIR}" --shared-file-dir="/home/hived/shm_dir" \
    --plugin=sql_serializer --psql-url="postgresql://hived@postgres/haf_block_log" \
    "$@" --dump-config > /dev/null 2>&1

  # add a default set of plugins that API nodes should run
  sed -i 's/^# plugin = .*$/plugin = node_status_api account_by_key account_by_key_api block_api condenser_api database_api json_rpc market_history market_history_api network_broadcast_api p2p rc_api state_snapshot transaction_status transaction_status_api wallet_bridge_api webserver/g' "$DATADIR/config.ini"

  # set a default logging config.  We will log the usual output both to stderr and to a log file in the
  # haf-datadir/logs/hived/default directory.  Rotate daily, keep for 30 days.
  sed -i 's|^# log-appender = .*$|log-appender = {"appender":"stderr","stream":"std_error","time_format":"iso_8601_microseconds"} {"appender":"p2p","file":"logs/hived/p2p/p2p.log","truncate":false,"time_format":"iso_8601_milliseconds", "rotation_interval": 86400, "rotation_limit": 2592000} {"appender": "default", "file": "logs/hived/default/default.log","truncate":false, "time_format": "iso_8601_milliseconds", "rotation_interval": 86400, "rotation_limit": 2592000}|;s|^log-logger = .*$|log-logger = {"name":"default","level":"info","appenders":["stderr", "default"]} {"name":"user","level":"debug","appenders":["stderr", "default"]} {"name":"p2p","level":"warn","appenders":["p2p"]}|' "$DATADIR/config.ini"
fi

if [ "$#" -gt 0 ]; then
  echo "Executing hived using additional command line arguments:" "$@"
else
  echo "Executing hived"
fi

exec /usr/local/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir="${DATADIR}" --shared-file-dir="/home/hived/shm_dir" \
  --plugin=sql_serializer --psql-url="postgresql://hived@postgres/haf_block_log" \
  "$@"
