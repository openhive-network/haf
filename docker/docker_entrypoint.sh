#! /bin/bash
set -euo pipefail

echo "Starting the container with user $(whoami) with uid $(id -u)"

if [ "${HIVED_UID}" -ne 0 ];
then
  echo "setting user hived uid to value ${HIVED_UID}"
  sudo -n usermod -o -u "${HIVED_UID}" hived
fi


SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTDIR/haf/scripts"

"$SCRIPTSDIR/copy_datadir.sh"


if sudo -Enu hived test ! -d "$DATADIR"
then
    echo "Data directory (DATADIR) $DATADIR does not exist. Exiting."
    exit 1
fi

if sudo -Enu hived test ! -d "$SHM_DIR" && test "$SHM_DIR" != "$DATADIR/blockchain"
then
    echo "Shared memory file directory (SHM_DIR) $SHM_DIR does not exist. Exiting."
    exit 1
fi

LOG_FILE="${DATADIR}/${LOG_FILE:-docker_entrypoint.log}"
sudo -n touch "$LOG_FILE"
sudo -n chown -Rc hived:users "$LOG_FILE"
sudo -n chmod a+rw "$LOG_FILE"

# shellcheck source=../scripts/common.sh
source "$SCRIPTSDIR/common.sh"

HAF_DB_STORE="$DATADIR/haf_db_store"
PGDATA=$HAF_DB_STORE/pgdata

export POSTGRES_VERSION=${POSTGRES_VERSION:-14}

DO_MAINTENANCE=0 #Allows to enter some maintenance mode (when postgres is started but hived not yet. Rather for internal debugging/development purposes)
PERFORM_DUMP=0
PERFORM_LOAD=0
BACKUP_SOURCE_DIR_NAME=""
MAINTENANCE_SCRIPT_NAME=""

stop_postresql() {
echo "Attempting to stop Postgresql..."

postgres_pid=0
if [ -f "/var/run/postgresql/$POSTGRES_VERSION-main.pid" ];
then
  postgres_pid=$(cat "/var/run/postgresql/$POSTGRES_VERSION-main.pid")
fi

sudo -n /etc/init.d/postgresql stop

echo "Waiting for postgres process: $postgres_pid finish..."
if [ "$postgres_pid" -ne 0 ];
then
  tail --pid="$postgres_pid" -f /dev/null || true
fi

echo "Postgres process: $postgres_pid finished."
}

perform_instance_dump() {
  backup_dir_name="${1}"
  sudo -n mkdir -p "${DATADIR}/${backup_dir_name}"
  sudo -n chmod -R 774 "${DATADIR}/${backup_dir_name}"
  sudo -n chown -R hived:users "${DATADIR}/${backup_dir_name}"

  "${SCRIPTSDIR}/dump_instance.sh" --backup-dir="${DATADIR}/${backup_dir_name}" --hived-executable-path=/home/hived/bin/hived \
    --override-existing-backup-dir --hived-db-role=hived \
    --hived-data-dir="$DATADIR" --shared-file-dir="$SHM_DIR" --exit-before-sync \
    --haf-db-name=haf_block_log --haf-db-admin=haf_admin \
    --haf-db-port=5432 --haf-db-host=/var/run/postgresql
}

perform_instance_load() {
  backup_dir_name="${1}"
  "${SCRIPTSDIR}/load_instance.sh" --backup-dir="${DATADIR}/${backup_dir_name}" --hived-executable-path=/home/hived/bin/hived \
    --hived-db-role=hived \
    --hived-data-dir="$DATADIR" --shared-file-dir="$SHM_DIR" --exit-before-sync \
    --haf-db-name=haf_block_log --haf-db-admin=haf_admin \
    --haf-db-port=5432 --haf-db-host=/var/run/postgresql

}

run_instance() {
{
sudo --user=hived -En /bin/bash << EOF
echo "Attempting to execute hived using additional command line arguments:" "${HIVED_ARGS[@]}"

if [ ! -f "$DATADIR/config.ini" ]; then
  echo "No config file exists, creating a default config file"

  /home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
    --data-dir="$DATADIR" --shared-file-dir="$SHM_DIR" \
    --plugin=sql_serializer --psql-url="dbname=haf_block_log host=/var/run/postgresql port=5432" \
    ${HIVED_ARGS[@]} --dump-config > /dev/null 2>&1

  # add a default set of plugins that API nodes should run
  sed -i 's/^plugin = .*$/plugin = node_status_api account_by_key account_by_key_api block_api condenser_api database_api json_rpc market_history market_history_api network_broadcast_api p2p rc_api reputation reputation_api state_snapshot transaction_status transaction_status_api wallet_bridge_api webserver/g' "$DATADIR/config.ini"

  # The transaction status plugin defaults to keeping transaction status history for 64000 blocks
  # (configured in "transaction-status-block-depth".  When replaying, it doesn't make sense to
  # track the status until we get within 64000 blocks of the current head block, because we'll
  # discard that data before the end of the replay.  There's a parameter,
  # "transaction-status-track-after-block", that allows us to skip processing until we reach that
  # block.  Unfortunately, this defaults to 0, so we end up doing a lot of useless work, adding
  # a few hours to a typical replay
  #
  # Here we try to estimate what block number is 64000 blocks behind the current block, based
  # on the current time and the time we know when block 80M was produced
  now_epoch=\$(date +%s)
  eightymil_epoch=\$(date +%s -d '2023-11-09 03:59:51')
  # if no blocks were skipped, we're currently at block:
  approximate_head_block=\$((80000000 + (now_epoch - eightymil_epoch) / 3))
  # go back an extra 10000 blocks to account for any blocks that may have been skipped
  # since block 80M.  There's little penalty for tracking a few tens of thousands
  # more than necessary.
  track_after_block=\$((approximate_head_block - 64000 - 10000))
  sed -i 's/^transaction-status-track-after-block = .*$/transaction-status-track-after-block = '"\$track_after_block"'/g' "$DATADIR/config.ini"
fi

/home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir="$DATADIR" --shared-file-dir="$SHM_DIR" \
  --plugin=sql_serializer --psql-url="dbname=haf_block_log host=/var/run/postgresql port=5432" \
  ${HIVED_ARGS[@]} 2>&1 | tee -i "$DATADIR/hived.log"
echo "$? Hived process finished execution."
EOF

stop_postresql

} &

job_pid=$!

jobs -l

echo "waiting for job finish: $job_pid."
local status=0
wait $job_pid || status=$?

return ${status}
}

# shellcheck disable=SC2317
cleanup () {
  echo "Performing cleanup...."
  hived_pid=$(pidof 'hived' || echo '') # pidof returns 1 if hived isn't running, which crashes the script
  echo "Hived pid: $hived_pid"

  jobs -l

  [[ -z "$hived_pid" ]] || sudo -n kill -INT "$hived_pid"

  echo "Waiting for hived finish..."
  [[ -z "$hived_pid" ]] || tail --pid="$hived_pid" -f /dev/null || true
  echo "Hived finish done."

  stop_postresql

  echo "Cleanup actions done."
}

prepare_pg_hba_file() {
  sudo -En /bin/bash << EOF
  echo -e "${PG_ACCESS}" > "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
  cat "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf.default" >> "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
  #cat "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
EOF
}

create_conf_d_directory_if_necessary() {
  # PostgreSQL looks for additional config files in this directory.  Usually, the user will bind-mount
  # config files into this location.  If they don't, create an empty directory so PostgreSQL doesn't
  # error out at startup
  if sudo --user=postgres -n [ ! -e "/home/hived/datadir/haf_postgresql_conf.d" ]; then
    sudo -n mkdir -p "/home/hived/datadir/haf_postgresql_conf.d"
    sudo -n chown -Rc postgres:postgres "/home/hived/datadir/haf_postgresql_conf.d"
  fi
}


# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
# If we do `trap cleanup INT QUIT TERM` directly, then using `exit` command anywhere
# in the script will exit the script without triggering the cleanup
trap 'exit' INT QUIT TERM
trap cleanup EXIT

# Be sure those directories exists and have right permissions
sudo --user=hived -n mkdir -p "$DATADIR/blockchain"

# PostgresQL configuration (postgresql.conf) has data_directory hardcoded as '/home/hived/datadir/haf_db_store/pgdata' and custom configuration path as
# /home/hived/datadir/haf_postgresql_conf.d/custom_postgres.conf. As such we need to make /home/hived/datadir a symbolinc link to actual data directory if
# variable $DATADIR is set to a non-default value.
if [[ "$DATADIR" != "/home/hived/datadir" ]]; then
  echo "Non-standard datadir requested: $DATADIR. Adding symbolic link and setting permissions..."
  sudo -n rm -rf /home/hived/datadir # Remove the default data directory
  sudo -n --user=hived ln -sf "$DATADIR" /home/hived/datadir # Add symbolic link to the new data directory in its place
fi

# Directory haf_db_store has to be world readable to avoid the following error:
# Error: /home/hived/datadir/haf_db_store/pgdata is not accessible; please fix the directory permissions (/home/hived/datadir/haf_db_store/ should be world readable)
sudo -n --user=hived mkdir -p -m 755 "$HAF_DB_STORE"

# Prepare HBA file before starting PostgreSQL
prepare_pg_hba_file

create_conf_d_directory_if_necessary

# Handle PGCTLTIMEOUT if set
[[ -n ${PGCTLTIMEOUT:-}  ]] && echo "PGCTLTIMEOUT = ${PGCTLTIMEOUT}" | sudo tee "/etc/postgresql/${POSTGRES_VERSION}/main/environment"
# cat "/etc/postgresql/${POSTGRES_VERSION}/main/environment"

if sudo --user=postgres -n [ ! -d "$PGDATA" -o ! -f "$PGDATA/PG_VERSION" ]; then
  sudo --user=hived -n mkdir -p "$PGDATA"
  sudo --user=hived -n mkdir -p "$HAF_DB_STORE/tablespace"
  sudo -n chown -Rc postgres:postgres "$HAF_DB_STORE"
  sudo -n chown -Rc postgres:postgres "$PGDATA"

  echo "Attempting to setup postgres instance: running initdb..."

  # initdb will refuse to run in a non-empty directory, so run initdb in an empty temporary directory then copy the files over
  mkdir -p /tmp/$$/pgdata
  sudo -n chown -Rc postgres:postgres /tmp/$$/pgdata
  sudo --user=postgres -n PGDATA="/tmp/$$/pgdata" "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/initdb"
  sudo --user=postgres -n bash -c "cd /tmp/$$/pgdata && tar cf - ." | sudo --user=postgres -n bash -c "cd \"$PGDATA\" && tar xf -"
  sudo -n rm -r /tmp/$$/pgdata

  echo "Attempting to setup postgres instance: running setup_postgres.sh..."

  sudo -n /home/haf_admin/haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="/home/hived/datadir/haf_db_store/tablespace"

  echo "Postgres instance setup completed."

  /home/haf_admin/haf/scripts/setup_db.sh --haf-db-admin=haf_admin --haf-db-name=haf_block_log --haf-app-user=haf_app_admin

  sudo -n /home/haf_admin/haf/scripts/setup_pghero.sh --database=haf_block_log
else
  echo "Attempting to setup postgres instance already containing HAF database..."

  # in case when container is restarted over already existing (and potentially filled) data directory, we need to be sure that docker-internal postgres has deployed HFM extension
  sudo -n /home/haf_admin/haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="/home/hived/datadir/haf_db_store/tablespace"
  sudo -n "/usr/share/postgresql/${POSTGRES_VERSION}/extension/hive_fork_manager_update_script_generator.sh" --haf-admin-account=haf_admin --haf-db-name=haf_block_log

  echo "Postgres instance setup completed."
fi

cd "$DATADIR"

# be sure postgres is running

sudo -n /etc/init.d/postgresql start

HIVED_ARGS=()

echo "Processing passed arguments...: $*"

SKIP_HIVED=0

while [ $# -gt 0 ]; do
  case "$1" in
    --execute-maintenance-script*)
      echo "Will run maintenance script $MAINTENANCE_SCRIPT_NAME..."
      MAINTENANCE_SCRIPT_NAME="${1#*=}"
      DO_MAINTENANCE=1
      ;;
    --dump-snapshot=*)
      echo "Dump snapshot option found..."
      BACKUP_SOURCE_DIR_NAME="${1#*=}"
      PERFORM_DUMP=1
      ;;
    --load-snapshot=*)
      BACKUP_SOURCE_DIR_NAME="${1#*=}"
      PERFORM_LOAD=1
      ;;
    --skip-hived)
      SKIP_HIVED=1
      # allow launching the container with only the database running, but not hived.  This is useful when you want to
      # examine the database, but there's some problem that causes hived to exit at startup, since hived exiting will
      # then shut down the container, taking the database with it.
      ;;
    *)
      echo "Attempting to collect unknown (hived) option: ${1}"
      HIVED_ARGS+=("$1")
      ;;
  esac
  shift
done

export HIVED_ARGS

echo "Attempting to execute hived using additional command line arguments:" "${HIVED_ARGS[@]}"

echo "${BASH_SOURCE[@]}"

status=0

if [ ${DO_MAINTENANCE} -eq 1 ];
then
  echo "Running maintance script located at ${MAINTENANCE_SCRIPT_NAME} using additional command line arguments:" "${HIVED_ARGS[@]}"
  $MAINTENANCE_SCRIPT_NAME ${HIVED_ARGS[@]}
elif [ ${PERFORM_DUMP} -eq 1 ];
then
  echo "Attempting to perform instance snapshot dump"
  perform_instance_dump "${BACKUP_SOURCE_DIR_NAME}"
elif [ ${PERFORM_LOAD} -eq 1 ];
then
  echo "Attempting to perform instance snapshot load"
  perform_instance_load "${BACKUP_SOURCE_DIR_NAME}"
elif [ ${SKIP_HIVED} -eq 1 ];
then
  echo "Not launching hived due to --skip-hived command-line option"
  echo "You can now connect to the database.  This this container will continue to exist until you shut it down"
  # launch a webserver on port 8091 so the docker healthcheck will pass.  We probably want
  # the healthcheck to pass so docker-compose will continue to launch dependent containers
  # like pgadmin.
  # The webserver running in the foreground will also act to keep this container running
  # until the docker image is stopped.
  mkdir -p /tmp/dummy-webserver
  cd /tmp/dummy-webserver
  /home/haf_admin/.local/share/pypoetry/venv/bin/python -m http.server 8091
else
  run_instance
  status=$?
fi

echo "Exiting docker entrypoint with status: ${status}..."
exit $status
