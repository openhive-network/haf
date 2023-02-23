#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=dump_instance.log
source ${SCRIPTPATH}/dump_load_common.sh true "Allows to dump hived and haf states." "  --override-existing-backup-dir   Erases backup directory and its contents" $@

validate_environment(){

  if [ ${ERASE_CURRENT} = true ];
  then
    rm -rf ${HIVED_SNAPSHOT_DIR}
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

  local call_hived_dump="${HIVED_EXECUTABLE_PATH}
  --data-dir=${DATA_DIR}
  --plugin=sql_serializer --psql-url=${POSTGRES_ACCESS}
  --plugin=state_snapshot --snapshot-root-dir=${BACKUP_DIR} --dump-snapshot=hived
  ${ADDITIONAL_HIVED_OPTIONS[@]}"

  ${call_hived_dump}

}

dump_database(){
  
  mkdir -p ${POSTGRES_BACKUP_DIR}

  local call_pg_dump="pg_dump -j ${JOBS} -Fd -f ${POSTGRES_BACKUP_DIR} --dbname=${POSTGRES_ACCESS}"

  ${call_pg_dump}

}



validate_environment

mkdir -p ${BACKUP_DIR}

dump_snapshot

dump_database

