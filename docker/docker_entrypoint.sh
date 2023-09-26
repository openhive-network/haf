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

if sudo -Enu hived test ! -d "$SHM_DIR" && test "$SHM_DIR" != "$DATADIR/blockchain"
then
    echo "Shared memory file directory (SHM_DIR) $SHM_DIR does not exist. Exiting."
    exit 1
fi

HAF_DB_STORE="$DATADIR/haf_db_store"
CUSTOM_POSTGRES_CONFIG="$DATADIR/haf_postgresql_conf.d/custom_postgres.conf"
PGDATA="$DATADIR/haf_db_store/pgdata"


SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTDIR/haf/scripts"

LOG_FILE="${DATADIR}/${LOG_FILE:-docker_entrypoint.log}"
sudo -n touch "$LOG_FILE"
sudo -n chown -Rc hived:users "$LOG_FILE"
sudo -n chmod a+rw "$LOG_FILE"

# shellcheck source=../scripts/common.sh
source "$SCRIPTSDIR/common.sh"

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

/home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir="$DATADIR" --shared-file-dir="$SHM_DIR" \
  --plugin=sql_serializer --psql-url="dbname=haf_block_log host=/var/run/postgresql port=5432" \
  ${HIVED_ARGS[@]} 2>&1 | tee -i hived.log
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

# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
# If we do `trap cleanup INT QUIT TERM` directly, then using `exit` command anywhere
# in the script will exit the script without triggering the cleanup
trap 'exit' INT QUIT TERM
trap cleanup EXIT


# Be sure those directories exists and have right permissions
sudo --user=hived -n mkdir -p "$DATADIR/blockchain"

# data_directory is hardcoded in postgresql.conf as '/home/hived/datadir/haf_db_store/pgdata' so we create symbolic link to location of HAF_DB_STORE
# If the link already exists (ie. the container was restarted rather than recreated) we forcinly recreate the link to avoid error:
# ln: failed to create symbolic link '/home/hived/datadir/haf_db_store/haf_db_store': File exists
test "$HAF_DB_STORE" = "/home/hived/datadir/haf_db_store" || sudo -n ln -sf "$HAF_DB_STORE" /home/hived/datadir/haf_db_store

CUSTOM_POSTGRES_CONFIG_DEFAULT="/home/hived/datadir/haf_postgresql_conf.d/custom_postgres.conf"
POSTGRES_CONFIG="/etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf"
if [[ "$CUSTOM_POSTGRES_CONFIG" != "$CUSTOM_POSTGRES_CONFIG_DEFAULT" ]] && ! grep -q "$CUSTOM_POSTGRES_CONFIG" "$POSTGRES_CONFIG"; then
	echo "include_if_exists = '$CUSTOM_POSTGRES_CONFIG'" | sudo --user=postgres tee --append "$POSTGRES_CONFIG"
fi

# Prepare HBA file before starting PostgreSQL
prepare_pg_hba_file

# Handle PGCTLTIMEOUT if set
[[ -n ${PGCTLTIMEOUT:-}  ]] && echo "PGCTLTIMEOUT = ${PGCTLTIMEOUT}" | sudo tee "/etc/postgresql/${POSTGRES_VERSION}/main/environment"
# cat "/etc/postgresql/${POSTGRES_VERSION}/main/environment"

if [ -d "$PGDATA" ]
then
  echo "Attempting to setup postgres instance already containing HAF database..."

  # in case when container is restarted over already existing (and potentially filled) data directory, we need to be sure that docker-internal postgres has deployed HFM extension
  sudo -n /home/haf_admin/haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="/home/hived/datadir/haf_db_store/tablespace"
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

  sudo -n /home/haf_admin/haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="/home/hived/datadir/haf_db_store/tablespace"

  echo "Postgres instance setup completed."

  /home/haf_admin/haf/scripts/setup_db.sh --haf-db-admin=haf_admin --haf-db-name=haf_block_log --haf-app-user=haf_app_admin

  sudo -n /home/haf_admin/haf/scripts/setup_pghero.sh --database=haf_block_log
fi

cd "$DATADIR"

# be sure postgres is running

sudo -n /etc/init.d/postgresql start

HIVED_ARGS=()

echo "Processing passed arguments...: $*"

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
  echo "Running maintance script located at $MAINTENANCE_SCRIPT_NAME"
  $MAINTENANCE_SCRIPT_NAME
elif [ ${PERFORM_DUMP} -eq 1 ];
then
  echo "Attempting to perform instance snapshot dump"
  perform_instance_dump "${BACKUP_SOURCE_DIR_NAME}"
elif [ ${PERFORM_LOAD} -eq 1 ];
then
  echo "Attempting to perform instance snapshot load"
  perform_instance_load "${BACKUP_SOURCE_DIR_NAME}"
else
  run_instance
  status=$?
fi

echo "Exiting docker entrypoint with status: ${status}..."
exit $status
