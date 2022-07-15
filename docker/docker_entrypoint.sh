#! /bin/bash

set -euo pipefail

set -x

SCRIPTDIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SCRIPTSDIR="$SCRIPTDIR/haf/scripts"

LOG_FILE=docker_entrypoint.log
source "$SCRIPTSDIR/common.sh"

ls /cache || true

cleanup () {
  echo "Performing cleanup...."
  hived_pid=$(pidof 'hived')
  echo "Hived pid: $hived_pid"
  
  jobs -l

  sudo -n kill -INT $hived_pid

  echo "Waiting for hived finish..."
  tail --pid=$hived_pid -f /dev/null || true
  echo "Hived finish done."

  postgres_pid=0
  if [ -f /var/run/postgresql/12-main.pid ];
  then
    postgres_pid=$(cat /var/run/postgresql/12-main.pid)
  fi

  sudo -n /etc/init.d/postgresql stop

  echo "Waiting for postgres process: $postgres_pid finish..."
  if [ "$postgres_pid" -ne 0 ];
  then
    tail --pid=$postgres_pid -f /dev/null || true
  fi 

  echo "postgres finish done."

  echo "Cleanup actions done."

  echo "cleanup `date`" >>  $HIVED_DATA_DIR/log || true
}

prepare_pg_hba_file() {
  sudo -En /bin/bash << EOF
  echo -e "${PG_ACCESS}" > /etc/postgresql/12/main/pg_hba.conf
  cat /etc/postgresql/12/main/pg_hba.conf.default >> /etc/postgresql/12/main/pg_hba.conf
  cat /etc/postgresql/12/main/pg_hba.conf
EOF
}

# What can be a difference to catch EXIT instead of SIGINT ? Found here: https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
#trap 'exit' INT QUIT TERM
#trap cleanup EXIT
trap cleanup INT QUIT TERM

prepare_pg_hba_file

ls /home/hived -lath
ls -lath /cache || true


if [ ! -d /home/hived/datadir ]; then
  sudo -n mkdir -p /home/hived/datadir
fi
if [ ! -d /home/hived/shm_dir ]; then
  sudo -n mkdir -p /home/hived/shm_dir
fi
if [ ! -f /home/hived/datadir/config.ini ]; then
  sudo -n cp /home/hived/config.ini /home/hived/datadir/config.ini
fi
if [ ! -d /home/hived/datadir/blockchain ]; then
  sudo -n mkdir /home/hived/datadir/blockchain
fi
if [ ! -f /home/hived/datadir/blockchain/block_log ]; then
  sudo -n cp /home/hived/block_log_5m/block_log /home/hived/datadir/blockchain/block_log
fi

env
if [[ "$NETWORK_TYPE" == "-mirrornet" && "$BLOCK_LOG_SUFFIX" == "-5m" ]]; then
  if [ ! -f /home/hived/datadir/faketime.rc ]; then
    echo "Calculating time offset to use with faketime. This is enabled only in mirrornet and 5m block log."
    let TIME_OFFSET=$(date -d "2016-09-15 19:47:21" "+%s")-$(date "+%s")
    echo $TIME_OFFSET | sudo -n tee /home/hived/datadir/faketime.rc
  fi
fi

set -x
echo "PGDATA $PGDATA"
sudo -n ls $PGDATA || true
sudo -n ls $HAF_DB_STORE || true
sudo -n ls /home/hived/datadir || true
sudo -n ls /home/hived/shm_dir || true


# Be sure this directory exists
mkdir --mode=777 -p /home/hived/datadir/blockchain

if [ -d $PGDATA ]
then
  sudo -n chown -c hived:hived /home/hived/datadir
  pushd /home/hived/datadir
  sudo -n chown -Rc hived:hived $(ls /home/hived/datadir -I haf_db_store)
  sudo -n chown -Rc hived:hived /home/hived/shm_dir
  popd

  echo "Attempting to setup postgres instance..."

  # in case when container is restarted over already existing (and potentially filled) data directory, we need to be sure that docker-internal postgres has deployed HFM extension
  sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="$HAF_DB_STORE/tablespace"
  echo "Postgres instance setup completed."
else
  sudo -n chown -Rc hived:hived /home/hived/datadir
  sudo -n chown -Rc hived:hived /home/hived/shm_dir
  sudo -n mkdir -p $PGDATA 
  sudo -n mkdir -p $HAF_DB_STORE/tablespace
  sudo -n chown -Rc postgres:postgres $HAF_DB_STORE
  
  echo "Attempting to setup postgres instance..."

  # Here is an exception against using /etc/init.d/postgresql script to manage postgres - maybe there is some better way to force initdb using regular script.
  sudo -nu postgres PGDATA=$PGDATA /usr/lib/postgresql/12/bin/pg_ctl initdb

  sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/haf_admin/build" --haf-database-store="$HAF_DB_STORE/tablespace"

  echo "Postgres instance setup completed."

  ./haf/scripts/setup_db.sh --haf-db-admin=haf_admin --haf-db-name=haf_block_log --haf-app-user=haf_app_admin
fi

cd /home/hived/datadir

# be sure postgres is running
sudo -n /etc/init.d/postgresql start

HIVED_ARGS=()
HIVED_ARGS+=("$@")
export HIVED_ARGS


echo "Attempting to execute hived using additional command line arguments: ${HIVED_ARGS[@]}"

echo $BASH_SOURCE

{
sudo -Enu hived /bin/bash << EOF
echo "Attempting to execute hived using additional command line arguments: ${HIVED_ARGS[@]}"

LD_PRELOAD=/home/hived/libfaketime/src/libfaketimeMT.so.1 \
FAKETIME_TIMESTAMP_FILE=/home/hived/datadir/faketime.rc \
/home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir=/home/hived/datadir --shared-file-dir=/home/hived/shm_dir \
    --plugin=sql_serializer --psql-url="dbname=haf_block_log host=/var/run/postgresql port=5432" \
      ${HIVED_ARGS[@]} 2>&1 | tee -i hived.log
echo "$? Hived process finished execution."
EOF
echo "$? Attempting to stop Postgresql..."

postgres_pid=0
if [ -f /var/run/postgresql/12-main.pid ];
then
  postgres_pid=$(cat /var/run/postgresql/12-main.pid)
fi

sudo -n /etc/init.d/postgresql stop

echo "Waiting for postgres process: $postgres_pid finish..."
if [ "$postgres_pid" -ne 0 ];
then
  tail --pid=$postgres_pid -f /dev/null || true
fi

echo "Postgres process: $postgres_pid finished."

} &

job_pid=$!

jobs -l

echo "waiting for job finish: $job_pid."
wait $job_pid || true

echo "Exiting docker entrypoint..."

