#!/usr/bin/env bash
set -Eeo pipefail

# This entrypoint script functions identically to the default one, except for how it deals with startup scripts:
# - if there is a database, it will run scripts in /docker-entrypoint-always-initdb.d/
# - pg_hba.conf will always be initialized from the environment variables, even if a database already exists

# Source the stock entrypoint file to get access to the functions it defines (without actually executing any of
# them)
source "$(which docker-entrypoint.sh)"

# The _main function below is identical to the one taken from the default postgres:14.9-bookworm entrypoint,
# but has different behavior when the database exists
_main() {
	# if first arg looks like a flag, assume we want to run postgres server
	if [ "${1:0:1}" = '-' ]; then
		set -- postgres "$@"
	fi

	if [ "$1" = 'postgres' ] && ! _pg_want_help "$@"; then
		docker_setup_env
		# setup data directories and permissions (when run as root)
		docker_create_db_directories
		if [ "$(id -u)" = '0' ]; then
			# then restart script as postgres user
			exec gosu postgres "$BASH_SOURCE" "$@"
		fi

		# only run initialization on an empty data directory
		if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
			docker_verify_minimum_env

			# check dir permissions to reduce likelihood of half-initialized database
			ls /docker-entrypoint-initdb.d/ > /dev/null

			docker_init_database_dir
			pg_setup_hba_conf "$@"

			# PGPASSWORD is required for psql when authentication is required for 'local' connections via pg_hba.conf and is otherwise harmless
			# e.g. when '--auth=md5' or '--auth-local=md5' is used in POSTGRES_INITDB_ARGS
			export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
			docker_temp_server_start "$@"

			docker_setup_db
			docker_process_init_files /docker-entrypoint-initdb.d/*

			docker_temp_server_stop
			unset PGPASSWORD
		else
			export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
			docker_temp_server_start "$@"
			docker_process_init_files /docker-entrypoint-always-initdb.d/*
			docker_temp_server_stop
			unset PGPASSWORD
		fi
		cat <<-'EOM'

			        PostgreSQL init process complete; ready for start up.

		EOM
	fi

	exec "$@"
}

_main "$@"
