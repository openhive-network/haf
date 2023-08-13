#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_postgres.log
# shellcheck source=../scripts/common.sh
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"

# This script configures a postgres cluster for HAF. This script must be run with root priviledges.
#
# - Installs a previously built hive_fork_manager PostgreSQL extension.
# - Creates all builtin HAF roles on the PostgreSQL cluster.
# - Creates an admin role (if missing) for the HAF database and adds it to the haf_administrators_group.

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Configure a PostgreSQL cluster for HAF installation."
    echo "OPTIONS:"
    echo "  --host=VALUE         Specify a PostgreSQL host location (defaults to /var/run/postgresql)."
    echo "  --port=NUMBER        Specify a PostgreSQL operating port (defaults to 5432)."
    echo "  --haf-binaries-dir=DIRECTORY_PATH"
    echo "                       Specify a directory containing pre-built HAF binaries to copy into the postgres cluster."
    echo "                       Usually it is a \`build\` subdirectory in the HAF source tree."
    echo "  --haf-admin-account=NAME  Specify a db role to be added to the 'haf_administrators_group'."
    echo "                       Specified role is created on the server if needed."
    echo "  --haf-database-store=DIRECTORY_PATH"
    echo "                       Specify a directory where the HAF database will be stored."
    echo "  --help               Display this help screen and exit."
    echo
}

deploy_builtin_roles() {
  local pg_access=("$@")
  echo "Attempting to deploy HAF builtin roles..."
  sudo -nu postgres psql -d postgres --echo-all --no-password "${pg_access[@]}" --variable=ON_ERROR_STOP=on -f "$SCRIPTPATH/haf_builtin_roles.sql"
}

setup_haf_storage_tablespace() {
  local pg_access=("$@")
  local haf_tablespace_path=${pg_access[-1]} # last argument is the tablespace path
  unset 'pg_access[-1]'
  local haf_tablespace_name=${pg_access[-1]} # second to last argument is the tablespace name
  unset 'pg_access[-1]'

  haf_tablespace_abs_path=$(realpath -m --no-symlinks "$haf_tablespace_path")

  TABLESPACE_PATH=$(sudo -nu postgres psql --quiet --tuples-only --no-align --no-psqlrc --dbname=postgres --no-password "${pg_access[@]}" --variable=ON_ERROR_STOP=on --file=- <<EOF
  SELECT COALESCE((SELECT pg_tablespace_location(oid)
                   FROM pg_tablespace where spcname = '$haf_tablespace_name'
                  ),
                  ''
                 ) AS TABLESPACE_PATH;
EOF
)

if [[ -n "$TABLESPACE_PATH" ]]; then
  if [ "$TABLESPACE_PATH" = "$haf_tablespace_abs_path" ]; then
      if [[ ! -d "$haf_tablespace_abs_path" || -z $(ls -A "$haf_tablespace_abs_path") ]]; then
        echo "WARNING: The tablespace $haf_tablespace_name already points to the specified location, but the target directory does not exists or is empty. Creating a new tablespace there."
        sudo -nu postgres psql --dbname=postgres --echo-all --no-password "${pg_access[@]}" --variable=ON_ERROR_STOP=on --file=- <<EOF
          DROP TABLESPACE $haf_tablespace_name;
EOF
      else
        echo "WARNING: The tablespace $haf_tablespace_name already exists at the specified location. Skipping another creation."
        return 0
      fi
    else
      echo "ERROR: The tablespace $haf_tablespace_name already exists, but points to a different location: $TABLESPACE_PATH. Aborting script execution."
      exit 2
  fi
fi

sudo --user=postgres -n mkdir -p "$haf_tablespace_abs_path"

sudo -nu postgres psql --dbname=postgres --echo-all --no-password "${pg_access[@]}" --variable=ON_ERROR_STOP=on --file=- <<EOF
  CREATE TABLESPACE $haf_tablespace_name OWNER $HAF_ADMIN_ACCOUNT LOCATION '$haf_tablespace_abs_path';
EOF

}

install_extension() {
  echo "Script path is: $SCRIPTPATH"
  local build_dir
  build_dir=$(realpath -e --relative-base="$SCRIPTPATH" "$1")
  build_dir=${build_dir%%[[:space:]]}
  echo "Attempting to install hive_fork_manager extenstion into PostgreSQL directories..."
  pushd "$build_dir" || return
  ninja install
  popd || return
}

HAF_ADMIN_ACCOUNT="haf_admin"
#HAF_APP_ADMIN_ACCOUNT="haf_app_admin"

HAF_TABLESPACE_NAME="haf_tablespace"
HAF_TABLESPACE_LOCATION="./haf_database_store"

HAF_BINARY_DIR="../build"
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --haf-binaries-dir=*)
        HAF_BINARY_DIR="${1#*=}"
        ;;
    --haf-admin-account=*)
        HAF_ADMIN_ACCOUNT="${1#*=}"
        ;;
    --haf-database-store=*)
        HAF_TABLESPACE_LOCATION="${1#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option."
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument."
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

POSTGRES_ACCESS=("--host=$POSTGRES_HOST" "--port=$POSTGRES_PORT")

if [ "$EUID" -ne 0 ]
  then echo "Please run as root."
  exit 1
fi

install_extension "$HAF_BINARY_DIR"

# Be sure PostgreSQL is started.
/etc/init.d/postgresql start

deploy_builtin_roles "${POSTGRES_ACCESS[@]}"
"$SCRIPTPATH/create_haf_admin_role.sh" "${POSTGRES_ACCESS[@]}" --haf-admin-account="$HAF_ADMIN_ACCOUNT"
setup_haf_storage_tablespace "${POSTGRES_ACCESS[@]}" "$HAF_TABLESPACE_NAME" "$HAF_TABLESPACE_LOCATION"

# Allow everyone to overwrite/remove our log
chmod a+w "$LOG_FILE"

