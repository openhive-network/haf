#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_pghero.log
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"

#
# Script installs [pghero](https://github.com/ankane/pghero) monitoring
# stuff into specified database. This script execution requires root
# privileges.
#

print_help() {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Script installs [pghero](https://github.com/ankane/pghero) monitoring stuff into specified database"
    echo "OPTIONS:"
    echo "  --host=VALUE         Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER        Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --database=VALUE     Allows to specify a PostgreSQL database (defaults to haf_block_log)"
    echo "  --help               Display this help screen and exit"
    echo
}

setup_pghero() {
  local pg_access="$1"
  echo "Attempting to install pghero stuff"
  sudo -nu postgres psql -d postgres -aw $pg_access -v ON_ERROR_STOP=on -f $SCRIPTPATH/pghero.sql
}

POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
POSTGRES_DATABASE="haf_block_log"

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --database=*)
        POSTGRES_DATABASE="${1#*=}"
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
    shift
done

POSTGRES_ACCESS="--host $POSTGRES_HOST --port $POSTGRES_PORT -d $POSTGRES_DATABASE"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Be sure PostgreSQL is started.
/etc/init.d/postgresql start

setup_pghero "$POSTGRES_ACCESS"

# Allow everyone to overwrite/remove our log
chmod a+w "$LOG_FILE"
