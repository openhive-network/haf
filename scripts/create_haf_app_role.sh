#! /bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_postgres.log
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"


print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to create a HAF app role on specified PostgreSQL instance"
    echo "OPTIONS:"
    echo "  --host=VALUE              Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER             Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --postgres-url=URL        Allows to specify PostgreSQL connection url directly"
    echo "  --haf-app-account=NAME    Allows to specify an account name to be added to the 'hive_applications_group' group."
    echo "  --public                  A public account will be created"
    echo "  --help                    Display this help screen and exit"
    echo
}

create_haf_app_account() {
  local pg_access="$1"
  local haf_app_account="$2"
  local is_public="$3"

  local base_group="hive_applications_group"
  local alter_to_public=""
  $is_public && alter_to_public="ALTER ROLE ${haf_app_account} SET query_supervisor.limits_enabled TO true;"

  psql -aw "$pg_access" -v ON_ERROR_STOP=on -f - <<EOF
DO \$$
BEGIN
    BEGIN
      CREATE ROLE $haf_app_account WITH LOGIN INHERIT IN ROLE hive_applications_group;
      EXCEPTION WHEN DUPLICATE_OBJECT THEN
      RAISE NOTICE '$haf_app_account role already exists';
    END;
    ${alter_to_public}
END
\$$;

EOF

}


HAF_APP_ACCOUNT="haf_app_admin"
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
POSTGRES_URL=""
PUBLIC=false

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --postgres-url=*)
        POSTGRES_URL="${1#*=}"
        ;;
    --haf-app-account=*)
        HAF_APP_ACCOUNT="${1#*=}"
        ;;
    --public)
        PUBLIC=true
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

if [ -z "$POSTGRES_URL" ]; then
  POSTGRES_ACCESS="postgresql://?dbname=haf_block_log&port=${POSTGRES_PORT}&host=${POSTGRES_HOST}"
else
  POSTGRES_ACCESS=$POSTGRES_URL
fi

echo $POSTGRES_ACCESS

create_haf_app_account "$POSTGRES_ACCESS" "$HAF_APP_ACCOUNT" ${PUBLIC}

