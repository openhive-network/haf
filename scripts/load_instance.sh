#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=load_instance.log
source ${SCRIPTPATH}/dump_load_common.sh false "Load hived and haf states." "" $@


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

load_database(){
  
  local db_parameters=()
  local script_db_parameters=()

  if [[ ! -z ${POSTGRES_HOST} ]]
  then
    script_db_parameters+=(--host=${POSTGRES_HOST})
    db_parameters+=(--host=${POSTGRES_HOST})
  fi

  if [[ ! -z ${POSTGRES_DATABASE} ]]
  then
    script_db_parameters+=(--haf-db-name=${POSTGRES_DATABASE})
    db_parameters+=(--dbname=${POSTGRES_DATABASE})
  fi

  if [[ ! -z ${POSTGRES_PORT} ]]
  then
    script_db_parameters+=(--port=${POSTGRES_PORT})
    db_parameters+=(--port=${POSTGRES_PORT})
  fi

  if [[ ! -z ${POSTGRES_USER} ]]
  then
    script_db_parameters+=(--haf-db-admin=${POSTGRES_USER})
    db_parameters+=(--username=${POSTGRES_USER})
  fi

  "${SCRIPTPATH}"/setup_db.sh --no-create-schema "${script_db_parameters[@]}"

  pg_restore            --section=pre-data  --disable-triggers                     "${db_parameters[@]}" ${POSTGRES_BACKUP_DIR}
  pg_restore -j ${JOBS} --section=data      --disable-triggers                     "${db_parameters[@]}" ${POSTGRES_BACKUP_DIR}
  pg_restore            --section=post-data --disable-triggers --clean --if-exists "${db_parameters[@]}" ${POSTGRES_BACKUP_DIR}

}


load_snapshot_and_run(){
  
  local hived_args=()
  hived_args+=(--data-dir="${DATA_DIR}")
  hived_args+=(--plugin=sql_serializer)
  hived_args+=(--psql-url="${HIVED_POSTGRES_ACCESS}")
  hived_args+=(--plugin=state_snapshot)
  hived_args+=(--snapshot-root-dir="${BACKUP_DIR}")
  hived_args+=(--load-snapshot=hived)
  hived_args+=("${ADDITIONAL_HIVED_OPTIONS[@]}")

  if [ "${HIVED_DB_ROLE}" != "${POSTGRES_USER}" ];
  then
    echo "Using HIVED_DB_ROLE: '${HIVED_DB_ROLE}', POSTGRES_USER: '${POSTGRES_USER}'"
    echo "Switching to separate Hived role..."
    sudo -Enu ${HIVED_DB_ROLE} "${HIVED_EXECUTABLE_PATH}" "${hived_args[@]}"
  else
    "${HIVED_EXECUTABLE_PATH}" "${hived_args[@]}"
  fi

}

validate_environment
load_database
load_snapshot_and_run
