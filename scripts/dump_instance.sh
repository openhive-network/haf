#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=dump_instance.log
source ${SCRIPTPATH}/dump_load_common.sh true "Dump hived and haf states." "  --override-existing-backup-dir   Erases backup directory and its contents." "$@"

validate_environment(){

  if [ ${ERASE_CURRENT} = true ];
  then
    if [ "${HIVED_DB_ROLE}" != "${POSTGRES_USER}" ];
    then
      echo "Switching to a separate hived role to erase previously generated snapshot..."
      run_as_user "${HIVED_DB_ROLE}" rm -rf "${HIVED_SNAPSHOT_DIR}"
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

haf_head_block(){
  psql "${POSTGRES_ACCESS}" -v ON_ERROR_STOP=1 -tAc "SELECT COALESCE(MAX(num), 0) FROM hafd.blocks;"
}

dump_snapshot(){

  # hived refuses to open a state that is behind its block log unless it replays. Replaying up to the
  # head HAF already holds applies no block, so the dumped state stays where it is.
  local head_block
  head_block=$(haf_head_block)
  if [ "${head_block}" -eq 0 ];
  then
    echo "The HAF database holds no blocks, there is no state to dump."
    exit 1
  fi

  local hived_options=()
  local option
  for option in "${ADDITIONAL_HIVED_OPTIONS[@]}"; do
    case "${option}" in
      --force-replay)
        echo "${option} would wipe the state that is to be dumped, exiting..."
        exit 1
        ;;
      --stop-at-block=*|--exit-at-block=*|--exit-before-sync|--replay-blockchain)
        echo "Ignoring ${option}: the dump stops at HAF's head block ${head_block} and exits."
        ;;
      *)
        hived_options+=("${option}")
        ;;
    esac
  done

  local hived_args=()
  hived_args+=(--data-dir="${DATA_DIR}")
  hived_args+=(--plugin=sql_serializer)
  hived_args+=(--psql-url="${HIVED_POSTGRES_ACCESS}")
  hived_args+=(--plugin=state_snapshot)
  hived_args+=(--snapshot-root-dir="${BACKUP_DIR}")
  hived_args+=(--dump-snapshot=hived)
  hived_args+=(--replay-blockchain)
  hived_args+=(--stop-at-block="${head_block}")
  hived_args+=(--exit-before-sync)
  hived_args+=("${hived_options[@]}")

  echo "Using HIVED_DB_ROLE: ${HIVED_DB_ROLE}, POSTGRES_USER: ${POSTGRES_USER}."

  if [ "${HIVED_DB_ROLE}" != "${POSTGRES_USER}" ];
  then
    echo "Switching to a separate hived role..."
    run_as_user "${HIVED_DB_ROLE}" "${HIVED_EXECUTABLE_PATH}" "${hived_args[@]}"
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

  # Dump all the extensions except for pg_cron
  pg_dump -j ${JOBS} -Fd -f "${POSTGRES_BACKUP_DIR}" "${db_parameters[@]}" -N cron -e hive_fork_manager -e plpgsql -e tablefunc -e pg_stat_statements
}


validate_environment

mkdir -p ${BACKUP_DIR}

dump_snapshot

dump_database
