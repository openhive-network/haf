#! /bin/bash

set -euo pipefail 

cleanup () {
  echo "Performing cleanup...."
  hived_pid=$(pidof 'hived')
  echo "Hived pid: $hived_pid"
  
  sudo -n kill -INT $hived_pid

  echo "Waiting for hived finish..."
  tail --pid=$hived_pid -f /dev/null || true
  echo "Hived finish done."

  sudo -n /etc/init.d/postgresql stop

  echo "Cleanup actions done."
}

# What can be a difference to catch EXIT instead of SIGINT ? Found here: https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509
#trap 'exit' INT QUIT TERM
#trap cleanup EXIT
trap cleanup INT QUIT TERM

if [ ! -d /home/hived/datadir ]
then
  sudo -n mkdir -p /home/hived/datadir
  sudo -n chown -Rc hived:hived /home/hived/datadir
fi

if [ ! -d $PGDATA ]
then
  sudo -n mkdir -p $PGDATA 
  sudo -n mkdir -p $HAF_DB_STORE/tablespace
  sudo -n chown -Rc postgres:postgres $HAF_DB_STORE
  
  # Here is an exception against using /etc/init.d/postgresql script to manage postgres - maybe there is some better way to force initdb using regular script.
  sudo -nu postgres PGDATA=$PGDATA /usr/lib/postgresql/12/bin/pg_ctl initdb

  sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/hived/hive_fork_manager" --haf-database-store="$HAF_DB_STORE/tablespace"

  ./haf/scripts/setup_db.sh --haf-db-admin=haf_admin --haf-db-name=haf_block_log --haf-db-owner=hive
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

/home/hived/bin/hived --webserver-ws-endpoint=0.0.0.0:${WS_PORT} --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} --p2p-endpoint=0.0.0.0:${P2P_PORT} \
  --data-dir=/home/hived/datadir --shared-file-dir=/home/hived/shm_dir \
    --plugin=sql_serializer --psql-url="dbname=haf_block_log host=/var/run/postgresql port=5432" \
      ${HIVED_ARGS[@]} 2>&1 | tee -i hived.log

echo "Hived process finished execution."

EOF
} &

wait

echo "Exiting docker entrypoint..."

