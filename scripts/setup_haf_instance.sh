#! /bin/bash

set -euo pipefail

LOG_FILE=setup_haf_instance.log

# Because this script should work as standalone script being just downloaded from gitlab repo, and next use internal
# scripts from a cloned repo, logging code is duplicated.

exec > >(tee -i "${LOG_FILE}") 2>&1

log_exec_params() {
  echo
  echo -n "$0 parameters: "
  for arg in "$@"; do echo -n "$arg "; done
  echo
}

log_exec_params "$@"

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "One-step setup for a HAF server instance"
    echo "OPTIONS:"
    echo "  --host=VALUE           Optionally specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER          Optionally specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --hived-data-dir=PATH  Optionally specify a path where hived node will store its data. For faster setup, put a recent blockchain/block_log and block_log.index file in this directory before running this script."
    echo "  --hived-option=OPTION  Optionally specify a hived option to be passed to the automatically spawned hived process (this option can be repeated to pass multiple hived options)."
    echo "  --option-file=FILE     Optionally specify a file containing other options specific to this script's arguments. This file cannot contain another --option-file option within it."
    echo "  --haf-database-store=DIRECTORY_PATH"
    echo "                         Optionally specify a directory where Postgres SQL data specific to the HAF database will be stored. "
    echo "  --haf-binaries-dir=PATH  Allows to specify a directory containing already built HAF binaries to be used as HAF instance setup. build. Defaults to ./build path"
    echo "  --help                 Display this help screen and exit"
    echo
}

HIVED_ACCOUNT="hived"
HIVED_DATADIR=""
HIVED_ARGS=() # Set of options to be directly passed to the spawned hived.
HIVED_SHARED_MEM_FILE_SIZE=24G

HAF_DB_NAME="haf_block_log"
HAF_DB_OWNER="haf_app_admin"
HAF_ADMIN_ACCOUNT="haf_admin"
HAF_TABLESPACE_LOCATION="./haf_database_store"

HAF_BINARY_DIR="./build"

POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432

add_hived_arg() {
  local arg="$1"
#  echo "Processing hived argument: ${arg}"

  case "$arg" in
    -d[\ ]*)
    echo "Explicit d directory specified to: ${arg#*[\ ]}"
    HIVED_DATADIR="${arg#*[\ ]}"
    ;;
  --data-dir=*)
    echo "Explicit data directory specified to: ${arg#*=}"
    HIVED_DATADIR="${arg#*=}"
    ;;
  --data-dir[\ ]*)
    echo "Explicit data directory specified to: ${arg#*[\ ]}"
    HIVED_DATADIR="${arg#*[\ ]}"
    ;;
    --shared-file-size=*)
    HIVED_SHARED_MEM_FILE_SIZE=${arg#*=}
    ;;
  *)
      HIVED_ARGS+=("$arg")
    ;;
  esac
}


process_option() {
  o="$1"
  case "$o" in
    --host=*)
        POSTGRES_HOST="${o#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${o#*=}"
        ;;
    --hived-data-dir=*)
        HIVED_DATADIR="${o#*=}"
        ;;
    --haf-database-store=*)
        HAF_TABLESPACE_LOCATION="${o#*=}"
  ;;
    --hived-option=*)
        option="${o#*=}"
        add_hived_arg "$option"
        ;;
    --haf-binaries-dir=*)
        HAF_BINARY_DIR="${o#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        print_help
        exit 2
        ;;
  esac

}

process_option_file() {
  local option_file="$1"
  local READ_OPTIONS=()
  IFS=

  mapfile -t <"$option_file" READ_OPTIONS
  echo "Read options: ${READ_OPTIONS[@]}"
  for o in ${READ_OPTIONS[@]}; do
#    echo "Processing a file option: $o"
    process_option "$o"
  done

}

while [ $# -gt 0 ]; do
  case "$1" in
    --option-file=*)
      filename="${1#*=}"
      process_option_file "$filename"
      ;;
    *)
      process_option "$1"
      ;;
  esac
  shift
done

spawn_hived() {
  local hived_binary_path=`realpath -e "$1"`

  local data_dir="$HIVED_DATADIR"
  local db_name="$HAF_DB_NAME"
  local pg_host="$POSTGRES_HOST"
  local pg_port="$POSTGRES_PORT"

  if [ -z "$data_dir" ]
  then
    echo "Using default data directory for hived node..."
  else
    if [ -d "$HIVED_DATADIR" ]
    then
      data_dir=`realpath -e "$HIVED_DATADIR"`
      echo "Changing an ownership of hived data directory: $data_dir..."
      sudo -n chown -Rc $HIVED_ACCOUNT:$HIVED_ACCOUNT "$data_dir"
    fi
    echo "Using explicit hived data directory: $data_dir"

    data_dir="--data-dir=\"$data_dir\""

  fi

  echo "Attempting to start hived process..."

  set -x # to allow logging of every spawned cmd

  # Use hived account for peer authentication.
  sudo -HEnu $HIVED_ACCOUNT "$hived_binary_path" $data_dir --shared-file-size=$HIVED_SHARED_MEM_FILE_SIZE --plugin=sql_serializer --psql-url="dbname=$db_name host=$pg_host port=$pg_port" --replay ${HIVED_ARGS[@]}

  set -x
}

if [ "$EUID" -eq 0 ]
  then echo "Please DO NOT run as root"
  exit 1
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

sudo -En "$SCRIPTPATH/setup_postgres.sh" --host="$POSTGRES_HOST" --port="$POSTGRES_PORT" --haf-admin-account="$HAF_ADMIN_ACCOUNT" --haf-binaries-dir="$HAF_BINARY_DIR" --haf-database-store="$HAF_TABLESPACE_LOCATION"

"$SCRIPTPATH"/setup_db.sh --host="$POSTGRES_HOST" --port="$POSTGRES_PORT" --haf-db-admin="$HAF_ADMIN_ACCOUNT" --haf-db-name="$HAF_DB_NAME" --haf-app-user="$HAF_DB_OWNER"

spawn_hived "$HAF_BINARY_DIR/hive/programs/hived/hived" 2>&1 | tee -i replay.log

