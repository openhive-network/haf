#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=load_instance.log
source ${SCRIPTPATH}/dump_load_common.sh false "Allows to load hived and haf states." "" $@


validate_environment(){
  if [[ ! -d ${HIVED_SNAPSHOT_DIR} ]]
  then
    echo "${HIVED_SNAPSHOT_DIR} does not exist on your filesystem, exiting..."
    exit 1
  fi
  if [[ ! -d ${POSTGRES_BACKUP_DIR} ]]
  then
    echo "${POSTGRES_BACKUP_DIR} does not exist on your filesystem, exiting..."
    exit 1
  fi
}

generate_script_db_parameters(){
  local script_db_parameters=""

  if [[ ! -z ${POSTGRES_HOST} ]]
  then
    script_db_parameters+=" --host=${POSTGRES_HOST}"
  fi

  if [[ ! -z ${POSTGRES_DATABASE} ]]
  then
    script_db_parameters+=" --haf-db-name=${POSTGRES_DATABASE}"
  fi

  if [[ ! -z ${POSTGRES_PORT} ]]
  then
    script_db_parameters+=" --port=${POSTGRES_PORT}"
  fi

  if [[ ! -z ${POSTGRES_USER} ]]
  then
    script_db_parameters+=" --haf-db-admin=${POSTGRES_USER}"
  fi
  
  echo ${script_db_parameters}
}

load_database(){
  
  "${SCRIPTPATH}"/setup_db.sh --no-create-schema $(generate_script_db_parameters)

  pg_restore            --section=pre-data  --disable-triggers                     -d ${POSTGRES_ACCESS} ${POSTGRES_BACKUP_DIR}
  pg_restore -j ${JOBS} --section=data      --disable-triggers                     -d ${POSTGRES_ACCESS} ${POSTGRES_BACKUP_DIR}
  pg_restore            --section=post-data --disable-triggers --clean --if-exists -d ${POSTGRES_ACCESS} ${POSTGRES_BACKUP_DIR}

}


load_snapshot_and_run(){
  
  local call_hived_load="${HIVED_EXECUTABLE_PATH} --data-dir=${DATA_DIR} --plugin=state_snapshot --snapshot-root-dir=${BACKUP_DIR}  --load-snapshot=hived --plugin=sql_serializer --psql-url=${HIVED_POSTGRES_ACCESS} ${ADDITIONAL_HIVED_OPTIONS[@]}"

  if [ ${HIVED_DB_ROLE} -neq ${POSTGRES_USER} ];
  then
    echo "Switching to separate Hived role..."
    sudo -Enu "${HIVED_DB_ROLE}" -- "${call_hived_load}"
  else
    ${call_hived_load}
  fi

}

validate_environment
load_database
load_snapshot_and_run
