#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=dump_instance.log
source ${SCRIPTPATH}/dump_load_common.sh true "Dump hived and haf states." "  --override-existing-backup-dir   Erases backup directory and its contents." "$@"

remove_snapshot(){
  if [ "${HIVED_DB_ROLE}" != "${POSTGRES_USER}" ];
  then
    echo "Switching to a separate hived role to erase the snapshot..."
    run_as_user "${HIVED_DB_ROLE}" rm -rf "${HIVED_SNAPSHOT_DIR}"
  else
    rm -rf ${HIVED_SNAPSHOT_DIR}
  fi
}

validate_environment(){

  if [ ${ERASE_CURRENT} = true ];
  then
    remove_snapshot

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

  local hived_log
  hived_log=$(mktemp)
  trap "rm -f -- $(printf '%q' "${hived_log}")" EXIT

  if [ "${HIVED_DB_ROLE}" != "${POSTGRES_USER}" ];
  then
    echo "Switching to a separate hived role..."
    run_as_user "${HIVED_DB_ROLE}" "${HIVED_EXECUTABLE_PATH}" "${hived_args[@]}" 2>&1 | tee "${hived_log}"
  else
    "${HIVED_EXECUTABLE_PATH}" "${hived_args[@]}" 2>&1 | tee "${hived_log}"
  fi

  # On open hived rewinds its state to its last irreversible block. A replay that stops at or below that
  # block applies nothing, so the snapshot holds this state. After an unclean stop HAF's irreversible head
  # can lag it: blocks hived made irreversible may still wait in sql_serializer's write-ahead log, which
  # hived replays only once it applies a block, and the dump never does.
  local state_head
  state_head=$(sed -nE 's/.*Blockchain state database is AT IRREVERSIBLE state specific to head block: ([0-9]+).*/\1/p' "${hived_log}" | tail -n 1)
  if [ -z "${state_head}" ];
  then
    remove_snapshot
    echo "Cannot find the block of the dumped hived state in hived's output, so it cannot be checked against HAF's irreversible head block ${head_block}. Let hived log to stderr and dump again."
    exit 1
  fi
  if [ "${state_head}" -ne "${head_block}" ];
  then
    remove_snapshot
    echo "hived's state is at its last irreversible block ${state_head}, but HAF's irreversible head block is ${head_block}: the dump would pair them. This happens when hived was not stopped cleanly. Run the HAF instance until HAF catches up with hived, stop hived cleanly and dump again."
    exit 1
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
