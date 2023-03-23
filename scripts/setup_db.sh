#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_db.log
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"

# Script reponsible for execution of all actions required to finish configuration of the database holding a HAF database
# Linux account executing this script, must be associated to the $DB_ADMIN role which allows to:
# Unix user executing given script should be a member of specified DB_ADMIN (haf_admin) SQL role, to allow peer authentication
# - DROP !!! the existing database (if present)
# - create target database
# - install the extension there

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to create and setup a database to be filled by HAF instance. DROPs already existing database !!!"
    echo "OPTIONS:"
    echo "  --host=VALUE                    Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER                   Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --haf-db-name=NAME              Allows to specify a name of database to store a HAF data"
    echo "  --haf-app-user=NAME             Allows to specify a name of database role to be specified as an APP user of HAF database."
    echo "                                  Can be specified multiple times, if user would like to add multiple roles."
    echo "                                  Role MUST be earlier created on pointed Postgres instance !!!"
    echo "                                  If omitted, defaults to haf_app_admin role."
    echo "  --haf-db-admin=NAME             Allows to specify a name of database admin role having permission to create the database"
    echo "                                  and install an extension inside."
    echo "                                  Role MUST be earlier created on pointed Postgres instance !!!"
    echo "                                  If omitted, defaults to haf_admin role."
    echo "  --no-create-schema              Skips the final steps of creating schema, extension and database roles"
    echo "  --help                          Display this help screen and exit"
    echo
}

DB_NAME="haf_block_log"
DB_ADMIN="haf_admin"
HAF_TABLESPACE_NAME="haf_tablespace"

DEFAULT_DB_USERS=("haf_app_admin")
DB_USERS=()
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
NO_CREATE_SCHEMA=false

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --haf-db-name=*)
        DB_NAME="${1#*=}"
        ;;
    --haf-app-user=*)
        USER="${1#*=}"
        DB_USERS+=($USER)
        DEFAULT_DB_USERS=() # clear all default users.
        ;;
    --haf-db-admin=*)
        DB_ADMIN="${1#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;
    --no-create-schema)
        NO_CREATE_SCHEMA=true
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
    shift
done

POSTGRES_ACCESS="--host $POSTGRES_HOST --port $POSTGRES_PORT"

DB_USERS+=("${DEFAULT_DB_USERS[@]}")

# Seems that -v does not work correctly together with -c. Altough it works fine when -f is used (variable substitution works then)
  
sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
  DROP DATABASE IF EXISTS "$DB_NAME";
  CREATE DATABASE "$DB_NAME" WITH OWNER $DB_ADMIN TABLESPACE ${HAF_TABLESPACE_NAME};
EOF


if [ ${NO_CREATE_SCHEMA} = true ]; then
    exit 0
fi


sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c 'CREATE SCHEMA hive;' 
sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c 'CREATE EXTENSION hive_fork_manager CASCADE;' 

for u in "${DB_USERS[@]}"; do
  sudo -Enu "$DB_ADMIN" psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
    GRANT CREATE ON DATABASE "$DB_NAME" TO $u;
EOF

done
