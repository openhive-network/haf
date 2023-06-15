#! /bin/bash
set -euo pipefail 



log_exec_params() {
  echo
  echo -n "$0 parameters: "
  for arg in "$@"; do echo -n "${arg} "; done
  echo
}


IS_ERASE_CURRENT_BACKUP_DIRECTORY_OPTION=$1
shift
GENERAL_HELP_DESCRIPTION=$1
shift
SPECFIC_OPTIONS_HELP_TEXT=$1
shift

log_exec_params "$@"


print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]... [<hived_option>]..."
    echo
    echo "${GENERAL_HELP_DESCRIPTION}"
    echo "OPTIONS:"
    echo "  --backup-dir=DIR                 Allows to specify where the dumps are located, required"


    echo "  --hived-executable-path=PATH     Allows to specify where the main executable is located, required"
    echo "  --hived-data-dir=DIR             Allows to specify where node data is located, required"


    echo "  --haf-db-name=NAME               Allows to specify a name of database to store HAF data, required"
    echo "  --haf-db-admin=NAME              Allows to specify a name of database admin role having permission to create the database"
    echo "  --hived-db-role=NAME             Allows to specify a name of database role having permission to write to the HAF database"

    echo "  --haf-db-host=VALUE              Allows to specify a PostgreSQL host location"
    echo "  --haf-db-port=NUMBER             Allows to specify a PostgreSQL operating port"
    echo "  --haf-db-jobs=NUMBER             Allows to specify how many processes are run during dump/restore"
    if [ ! -z "${SPECFIC_OPTIONS_HELP_TEXT}" ] 
    then
      echo "${SPECFIC_OPTIONS_HELP_TEXT}"
    fi
    echo "  --help                           Display this help screen and exit"
    echo
}


BACKUP_DIR=""
HIVED_EXECUTABLE_PATH=""
DATA_DIR=""
ADDITIONAL_HIVED_OPTIONS=()

POSTGRES_DATABASE=""
POSTGRES_USER=""
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT="5432"
POSTGRES_URL=""

HIVED_DB_ROLE=""
HIVED_POSTGRES_URL=""

JOBS=3
ERASE_CURRENT=false


set_postgres_jobs_option(){
    JOBS="${1#*=}"
}


while [ $# -gt 0 ]; do
  case "$1" in
    --backup-dir=*)
        BACKUP_DIR="${1#*=}"
        ;;
    --hived-executable-path=*)
        HIVED_EXECUTABLE_PATH="${1#*=}"
        ;;
    --data-dir=*)
        DATA_DIR="${1#*=}"
        ;;
    --hived-data-dir=*)
        DATA_DIR="${1#*=}"
        ;;
    --haf-db-admin=*)
        POSTGRES_USER="${1#*=}"
        if [ -z ${HIVED_DB_ROLE} ]
        then
          HIVED_DB_ROLE="${1#*=}"
        fi
        ;;
    --hived-db-role=*)
        HIVED_DB_ROLE="${1#*=}"
        ;;
    --haf-db-name=*)
        POSTGRES_DATABASE="${1#*=}"
        ;;
    --haf-db-host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --haf-db-port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --haf-db-jobs=*)
        set_postgres_jobs_option $1
        ;;
    -j=*)
        set_postgres_jobs_option $1
        ;;
    --override-existing-backup-dir)
        if [ ${IS_ERASE_CURRENT_BACKUP_DIRECTORY_OPTION} = true ]
        then
            ERASE_CURRENT=true
        else
            ADDITIONAL_HIVED_OPTIONS+=("$1")
        fi
        ;;
    --help)
        print_help ${GENERAL_HELP_DESCRIPTION} ${SPECFIC_OPTIONS_HELP_TEXT}
        exit 0
        ;;
     -*)
        ADDITIONAL_HIVED_OPTIONS+=("$1")
        ;;
     *)
        ADDITIONAL_HIVED_OPTIONS+=("$1")
        ;;
    esac
    shift
done


if [ -z "${POSTGRES_URL}" ]
then
  POSTGRES_ACCESS="host=${POSTGRES_HOST} port=${POSTGRES_PORT} dbname=${POSTGRES_DATABASE} user=${POSTGRES_USER}"
else
  POSTGRES_ACCESS=${POSTGRES_URL}
fi

if [ -z "${HIVED_POSTGRES_URL}" ]
then
  HIVED_POSTGRES_ACCESS="host=${POSTGRES_HOST} port=${POSTGRES_PORT} dbname=${POSTGRES_DATABASE} user=${HIVED_DB_ROLE}"
else
  HIVED_POSTGRES_ACCESS=${HIVED_POSTGRES_URL}
fi

if [ -z ${BACKUP_DIR} ] || [ -z ${HIVED_EXECUTABLE_PATH} ] || [ -z ${DATA_DIR} ] || [ -z ${POSTGRES_DATABASE} ] 
then
  echo "Missing required option"
  print_help ${GENERAL_HELP_DESCRIPTION} ${SPECFIC_OPTIONS_HELP_TEXT}
  exit 0
fi

exec > >(tee "${DATA_DIR}/${LOG_FILE}") 2>&1


echo Script $0 running with options:
echo --backup-dir=${BACKUP_DIR}
echo --hived-executable-path=${HIVED_EXECUTABLE_PATH}
echo --hived-data-dir=${DATA_DIR}
echo --haf-db-admin=${POSTGRES_USER}
echo --haf-db-name=${POSTGRES_DATABASE}
echo --postgres-host=${POSTGRES_HOST}
echo --postgres-port=${POSTGRES_PORT}
echo --postgres-jobs=${JOBS}
if [ ${IS_ERASE_CURRENT_BACKUP_DIRECTORY_OPTION} = true ]
then
    echo --override-existing-backup-dir
fi
if [ ! -z ${ADDITIONAL_HIVED_OPTIONS+x} ]
then
  echo "Additional hived options="${ADDITIONAL_HIVED_OPTIONS}
fi

HIVED_SNAPSHOT_DIR=${BACKUP_DIR}/hived
POSTGRES_BACKUP_DIR=${BACKUP_DIR}/db
SHARED_FILE=${DATA_DIR}/blockchain/shared_memory.bin
BLOCK_LOG_ARTIFACTS_FILE=${DATA_DIR}/blockchain/block_log.artifacts
