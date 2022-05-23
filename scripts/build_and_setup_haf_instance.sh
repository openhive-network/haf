#! /bin/bash

set -euo pipefail

LOG_FILE=build_and_setup_haf_instance.log

# Because this script should work as standalone script being just downloaded from gitlab repo, and next use internal
# scripts from a cloned repo, logging code is duplicated.

exec > >(tee "${LOG_FILE}") 2>&1

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
    echo "  --branch=branch        Optionally specify a branch to checkout and build. Defaults to develop branch."
    echo "  --use-source-dir=PATH  Allows to specify explicit source directory instead of performing git checkout."
    echo "  --help                 Display this help screen and exit"
    echo
}

HIVED_ACCOUNT="hived"
HIVED_DATADIR=""
HIVED_ARGS=() # Set of options to be directly passed to the spawned hived.

HAF_DB_NAME="haf_block_log"
HAF_DB_OWNER="haf_app_admin"
HAF_ADMIN_ACCOUNT="haf_admin"
HAF_TABLESPACE_LOCATION="./haf_database_store"

HAF_BINARY_DIR="./build"
HAF_SOURCE_DIR=""
HAF_BRANCH=develop
HAF_REPO_URL="https://gitlab.syncad.com/hive/haf.git"
HAF_CMAKE_ARGS=()

POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432

add_hived_arg() {
  local arg="$1"
#  echo "Processing hived argument: ${arg}"
  HIVED_ARGS+=("--hived-option=${arg}")
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
    --branch=*)
        HAF_BRANCH="${o#*=}"
        ;;
    --use-source-dir=*)
        HAF_SOURCE_DIR="${o#*=}"
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

do_cleanup() {
  echo "Performing cleanup of build directory..."
  rm -vrf "$HAF_BINARY_DIR"
  echo "Cleanup done."
}

do_clone() {
  local branch=$1
  local src_dir="$2"
  echo "Cloning branch: $branch from $HAF_REPO_URL ..."
  git clone --recurse-submodules --shallow-submodules --single-branch --depth=1 --branch "$branch" -- "$HAF_REPO_URL" "$src_dir"
}

if [ "$EUID" -eq 0 ]
  then echo "Please DO NOT run as root"
  exit 1
fi

do_cleanup

if [ -z "$HAF_SOURCE_DIR" ] 
then
  HAF_SOURCE_DIR="./haf-$HAF_BRANCH"

  echo "Performing cleanup of source directory: '$HAF_SOURCE_DIR' ..."
  rm -vrf "$HAF_SOURCE_DIR"
  echo "Cleanup done."

  do_clone "$HAF_BRANCH" "$HAF_SOURCE_DIR"
fi

SCRIPTPATH="$HAF_SOURCE_DIR/scripts"

sudo -n "$SCRIPTPATH/setup_ubuntu.sh" --haf-admin-account="$HAF_ADMIN_ACCOUNT" --hived-account="$HIVED_ACCOUNT"
time "$SCRIPTPATH/build.sh" --haf-source-dir="$HAF_SOURCE_DIR" --haf-binaries-dir="$HAF_BINARY_DIR" "$@" hived extension.hive_fork_manager

"$SCRIPTPATH/setup_haf_instance.sh" --host="$POSTGRES_HOST" --port="$POSTGRES_PORT" --haf-binaries-dir="$HAF_BINARY_DIR" "${HIVED_ARGS[@]}"

