#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FILE=setup_postgres.log
source "$SCRIPTPATH/common.sh"

log_exec_params "$@"


print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to create a HAF app public role on specified PostgreSQL instance"
    echo "First it cleans up the role if already exits"
    echo "It creates a tablespace dedicated to the public role and make it its default"
    echo "Adds the public role to the list of limited users in option 'query_supervisor.limited_users'"
    echo "Prerequisites"
    echo "1. installed query supervisor"
    echo "2. in postgresql.conf: shared_preload_libraries = 'libquery_supervisor.so'"
    echo "OPTIONS:"
    echo "  --host=VALUE                   Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --only-clean                   Only removes a public role, all its contexts and its dedicated tablespace"
    echo "  --port=NUMBER                  Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --postgres-url=URL             Allows to specify PostgreSQL connection url directly"
    echo "  --haf-app-account=NAME         Allows to specify an account name to be added to the `hive_applications_group` group."
    echo "  --tablespace-path=PATH         Path to place on disk where limited tablespace for the user will be placed"
    echo "  --tablespace-max-size=NUMBER   Size limit of public tablespace in GB. Default is 2"
    echo "  --tablespace-name=TEXT         Name of a public tablespace. Default 'public_tablespace'"
    echo "  --help                         Display this help screen and exit"
    echo
}

cleanup_public_user() {
  psql -aw "$POSTGRES_ACCESS" -v ON_ERROR_STOP=off -f - <<EOF
SELECT hive.app_remove_context( hc.name ) FROM hive.contexts as hc WHERE owner = '${HAF_APP_ACCOUNT}';
DROP OWNED BY ${HAF_APP_ACCOUNT} CASCADE;
DROP ROLE IF EXISTS ${HAF_APP_ACCOUNT};
DROP TABLESPACE IF EXISTS ${HAF_PUBLIC_TABLESPACE_NAME};

EOF

echo "Removed role '${HAF_APP_ACCOUNT}' and its dedicated tablespace ${HAF_PUBLIC_TABLESPACE_NAME}"
}


create_user_with_tablespace() {
  mkdir -p "${HAF_PUBLIC_TABLESPACE_PATH}"
  sudo chown postgres "${HAF_PUBLIC_TABLESPACE_PATH}"

  psql -aw "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -f - <<EOF
CREATE TABLESPACE ${HAF_PUBLIC_TABLESPACE_NAME} OWNER postgres LOCATION '${HAF_PUBLIC_TABLESPACE_PATH}';
DO \$$
  DECLARE
    __name TEXT;
  BEGIN
    CREATE ROLE ${HAF_APP_ACCOUNT} WITH LOGIN INHERIT IN ROLE hive_applications_group;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE '${HAF_APP_ACCOUNT} role already exists';

    FOR __name IN SELECT spcname FROM pg_tablespace WHERE spcname != '${HAF_PUBLIC_TABLESPACE_NAME}'
      LOOP
        EXECUTE 'REVOKE CREATE ON TABLESPACE ' || __name || ' FROM ${HAF_APP_ACCOUNT}';
      END LOOP;

    EXECUTE 'REVOKE TEMPORARY ON DATABASE ' || current_catalog || ' FROM ${HAF_APP_ACCOUNT}';
  END;
\$$;

GRANT CREATE ON TABLESPACE ${HAF_PUBLIC_TABLESPACE_NAME} TO ${HAF_APP_ACCOUNT};
ALTER ROLE ${HAF_APP_ACCOUNT} SET default_tablespace TO ${HAF_PUBLIC_TABLESPACE_NAME};
ALTER ROLE ${HAF_APP_ACCOUNT} SET query_supervisor.limited_users TO ${HAF_APP_ACCOUNT};
SELECT pg_reload_conf();

EOF

echo "Added role '${HAF_APP_ACCOUNT}' and its dedicated tablespace ${HAF_PUBLIC_TABLESPACE_NAME} on ${HAF_PUBLIC_TABLESPACE_PATH}"
}


HAF_APP_ACCOUNT="haf_public_app_user"
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
HAF_PUBLIC_TABLESPACE_PATH="/tmp/haf_public_tablespace"
HAF_PUBLIC_TABLESPACE_NAME='public_tablespace'
POSTGRES_URL=""
ONLY_CLEAN="";

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --only-clean)
        ONLY_CLEAN=true;
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
    --tablespace-path=*)
        HAF_PUBLIC_TABLESPACE_PATH="${1#*=}"
        ;;
    --tablespace-name=*)
        HAF_PUBLIC_TABLESPACE_NAME="${1#*=}"
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

cleanup_public_user

if [ -z "${ONLY_CLEAN}" ] ; then
  create_user_with_tablespace
fi



