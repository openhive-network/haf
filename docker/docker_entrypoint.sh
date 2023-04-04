#! /bin/bash

set -euo pipefail

echo "Starting the container with user $(whoami) with uid $(id -u)"

if [ "${HIVED_UID}" -ne 0 ];
then
  echo "setting user hived uid to value ${HIVED_UID}"
  sudo -n usermod -o -u "${HIVED_UID}" hived
fi


if sudo -Enu hived test ! -d "$DATADIR"
then
    echo "Data directory (DATADIR) $DATADIR does not exist. Exiting."
    exit 1
fi

if sudo -Enu hived test ! -d "$SHM_DIR"
then
    echo "Shared memory file directory (SHM_DIR) $SHM_DIR does not exist. Exiting."
    exit 1
fi

HAF_DB_STORE=$DATADIR/haf_db_store
PGDATA=$DATADIR/haf_db_store/pgdata


SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTDIR/haf/scripts"

LOG_FILE="${DATADIR}/${LOG_FILE:-docker_entrypoint.log}"
sudo -n touch $LOG_FILE
sudo -n chown -Rc hived:users $LOG_FILE
sudo -n chmod a+rw "$LOG_FILE"

# shellcheck source=../scripts/common.sh
source "$SCRIPTSDIR/common.sh"

export POSTGRES_VERSION=${POSTGRES_VERSION:-14}

cleanup () {
  echo "Performing cleanup...."
  hived_pid=$(pidof 'hived' || echo '') # pidof returns 1 if hived isn't running, which crashes the script 
  echo "Hived pid: $hived_pid"

  jobs -l

  [[ -z "$hived_pid" ]] || sudo -n kill -INT "$hived_pid"

  echo "Waiting for hived finish..."
  [[ -z "$hived_pid" ]] || tail --pid="$hived_pid" -f /dev/null
  echo "Hived finish done."

  postgres_pid=0
  if [ -f "/var/run/postgresql/${POSTGRES_VERSION}-main.pid" ];
  then
    postgres_pid=$(cat "/var/run/postgresql/${POSTGRES_VERSION}-main.pid")
  fi

  sudo -n /etc/init.d/postgresql stop

  echo "Waiting for postgres process: $postgres_pid finish..."
  if [ "$postgres_pid" -ne 0 ];
  then
    tail --pid="$postgres_pid" -f /dev/null || true
  fi

  echo "postgres finish done."

  echo "Cleanup actions done."
}

prepare_pg_hba_file() {
  sudo -En /bin/bash << EOF
  echo -e "${PG_ACCESS}" > "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
  cat "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf.default" >> "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
  cat "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"
EOF
}

# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
# If we do `trap cleanup INT QUIT TERM` directly, then using `exit` command anywhere
# in the script will exit the script without triggering the cleanup
trap 'exit' INT QUIT TERM
trap cleanup EXIT


# Be sure those directories exists and have right permissions
sudo --user=hived -n mkdir -p "$DATADIR/blockchain"

# data_directory is hardcoded in postgresql.conf as '/home/hived/datadir/haf_db_store/pgdata' so we create symbolic link to location of HAF_DB_STORE
test "$HAF_DB_STORE" = "/home/hived/datadir/haf_db_store" || sudo -n ln -s "$HAF_DB_STORE" /home/hived/datadir/haf_db_store


if [ -d "$PGDATA" ]
then
  echo "Attempting to setup postgres instance already containing HAF database..."

  # in case when container is restarted over already existing (and potentially filled) data directory, we need to be sure that docker-internal postgres has deployed HFM extension
  sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="$HAF_DB_STORE/tablespace"
  sudo -n "/usr/share/postgresql/${POSTGRES_VERSION}/extension/hive_fork_manager_update_script_generator.sh" --haf-admin-account=haf_admin --haf-db-name=haf_block_log

  echo "Postgres instance setup completed."
else
  sudo --user=hived -n mkdir -p "$PGDATA"
  sudo --user=hived -n mkdir -p "$HAF_DB_STORE/tablespace"
  sudo -n chown -Rc postgres:postgres "$HAF_DB_STORE"
  sudo -n chown -Rc postgres:postgres "$PGDATA"

  echo "Attempting to setup postgres instance: running initdb..."
 
  # Here is an exception against using /etc/init.d/postgresql script to manage postgres - maybe there is some better way to force initdb using regular script.
  sudo --user=postgres -n PGDATA="$PGDATA" "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/initdb"

  echo "Attempting to setup postgres instance: running setup_postgres.sh..."

  sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="$HAF_DB_STORE/tablespace"

  echo "Postgres instance setup completed."

  ./haf/scripts/setup_db.sh --haf-db-admin=haf_admin --haf-db-name=haf_block_log --haf-app-user=haf_app_admin

  sudo -n ./haf/scripts/setup_pghero.sh --database=haf_block_log
fi

cd "$DATADIR"

# be sure postgres is running and reload pg_hba file
prepare_pg_hba_file
sudo -n /etc/init.d/postgresql restart

HIVED_ARGS=()
HIVED_ARGS+=("$@")
export HIVED_ARGS

echo "Attempting to execute hived using additional command line arguments:" "${HIVED_ARGS[@]}"

echo "${BASH_SOURCE[@]}"

{
sudo --user=hived -En /bin/bash << EOF
echo "Attempting to execute hived using additional command line arguments:" "${HIVED_ARGS[@]}"

/home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir="$DATADIR" --shared-file-dir="$SHM_DIR" \
  --plugin=sql_serializer --psql-url="dbname=haf_block_log host=/var/run/postgresql port=5432" \
  ${HIVED_ARGS[@]} 2>&1 | tee -i hived.log
echo "$? Hived process finished execution."
EOF
echo "$? Attempting to stop Postgresql..."

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

} &

job_pid=$!

jobs -l

echo "waiting for job finish: $job_pid."
status=0
wait $job_pid || status=$?

echo "Exiting docker entrypoint..."
exit $status
