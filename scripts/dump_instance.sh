#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=dump_instance.log
source ${SCRIPTPATH}/dump_load_common.sh true "Allows to dump hived and haf states." "  --override-existing-backup-dir   Erases backup directory and its contents" $@

validate_environment(){

  if [ ${ERASE_CURRENT} = true ];
  then
    if [ "${HIVED_DB_ROLE}" != "${POSTGRES_USER}" ];
    then
      echo "Switching to separate Hived role to erase previously generated snapshot..."
      sudo -Enu ${HIVED_DB_ROLE} rm -rf ${HIVED_SNAPSHOT_DIR}
    else
      rm -rf ${HIVED_SNAPSHOT_DIR}
    fi

    rm -rf ${POSTGRES_BACKUP_DIR}

  else
    if [[ -d ${HIVED_SNAPSHOT_DIR} ]]
    then
      echo "${HIVED_SNAPSHOT_DIR} exists on your filesystem, exiting..."
      echo "Use --override-existing-backup-dir or choose another --backup-dir"
      exit 1
    fi
    if [[ -d ${POSTGRES_BACKUP_DIR} ]]
    then
      echo "${POSTGRES_BACKUP_DIR} exists on your filesystem, exiting..."
      echo "Use --override-existing-backup-dir or choose another --backup-dir"
      exit 1
    fi
  fi
}

dump_snapshot(){

  local hived_args=()
  hived_args+=(--data-dir="${DATA_DIR}")
  hived_args+=(--plugin=sql_serializer)
  hived_args+=(--psql-url="${HIVED_POSTGRES_ACCESS}")
  hived_args+=(--plugin=state_snapshot)
  hived_args+=(--snapshot-root-dir="${BACKUP_DIR}")
  hived_args+=(--dump-snapshot=hived)
  hived_args+=("${ADDITIONAL_HIVED_OPTIONS[@]}")

  echo "Using HIVED_DB_ROLE: ${HIVED_DB_ROLE}, POSTGRES_USER: ${POSTGRES_USER}"

  if [ "${HIVED_DB_ROLE}" != "${POSTGRES_USER}" ];
  then
    echo "Switching to separate Hived role..."
    sudo -Enu ${HIVED_DB_ROLE} "${HIVED_EXECUTABLE_PATH}" "${hived_args[@]}"
  else
    "${HIVED_EXECUTABLE_PATH}" "${hived_args[@]}"
  fi

}

dump_database(){
  
  mkdir -p ${POSTGRES_BACKUP_DIR}

  local db_parameters=()

  if [[ ! -z ${POSTGRES_HOST} ]]
  then
    db_parameters+=(--host=${POSTGRES_HOST})
  fi

  if [[ ! -z ${POSTGRES_DATABASE} ]]
  then
    db_parameters+=(--dbname=${POSTGRES_DATABASE})
  fi

  if [[ ! -z ${POSTGRES_PORT} ]]
  then
    db_parameters+=(--port=${POSTGRES_PORT})
  fi

  if [[ ! -z ${POSTGRES_USER} ]]
  then
    db_parameters+=(--username=${POSTGRES_USER})
  fi

  pg_dump -j ${JOBS} -Fd -f "${POSTGRES_BACKUP_DIR}" "${db_parameters[@]}"
}


validate_environment

mkdir -p ${BACKUP_DIR}

dump_snapshot

dump_database
