#!/usr/bin/env bash
# Maintenance script of the shared HAF service, run by the HAF entrypoint once
# PostgreSQL is up (start.sh hands it over):
#
# 1. installs the clone API (admin.sql) into the haf_shared database and sets
#    the consumer role's password from <root>/consumer.password;
# 2. once per seeded version, freezes haf_template: a clone of haf_block_log
#    that no one may connect to, with its head block recorded. haf_block_log
#    itself stays connectable, because the entrypoint checks and updates the
#    extension in it on every start;
# 3. reaps run databases every HAF_SHARED_REAP_INTERVAL seconds, then serves
#    as the image's sleep_infinity.sh does.
#
# Environment: HAF_FIXTURE_COMMIT, HAF_SHARED_ROOT (as start.sh),
# HAF_SHARED_RUN_TTL (default '6 hours'), HAF_SHARED_REAP_INTERVAL (default 300).
set -euo pipefail

commit="${HAF_FIXTURE_COMMIT:?}"
root="${HAF_SHARED_ROOT:?}"
ttl="${HAF_SHARED_RUN_TTL:-6 hours}"
interval="${HAF_SHARED_REAP_INTERVAL:-300}"
here="$(cd "$(dirname "$0")" && pwd -P)"

psql_pg() {
    sudo -nu postgres psql -X -q -v ON_ERROR_STOP=1 "$@"
}

password_file="$root/consumer.password"
if ! password="$(sudo -n cat "$password_file" 2>/dev/null)"; then
    echo "no consumer password at $password_file: write the HAF_PG_PASSWORD secret consumers are given there (root, 0600)" >&2
    exit 1
fi
if [[ ! "$password" =~ ^[A-Za-z0-9._~+/=-]{16,128}$ ]]; then
    echo "$password_file must hold 16-128 characters of [A-Za-z0-9._~+/=-]" >&2
    exit 1
fi

psql_pg -d postgres <<'EOF'
select 'create database haf_shared' where not exists (select 1 from pg_database where datname = 'haf_shared')
\gexec
EOF
psql_pg -d haf_shared -f "$here/admin.sql"
# On stdin, never argv; the charset checked above holds no quote.
psql_pg -d postgres <<EOF
set log_statement = 'none';
alter role haf_shared_consumer password '$password';
EOF

if [ "$(psql_pg -d haf_shared -Atc "select count(*) from haf_shared.template")" != 1 ]; then
    echo "freezing haf_template from haf_block_log of $commit"
    head_block="$(psql_pg -d haf_block_log -Atc 'select max(num) from hafd.blocks')"
    if [[ ! "$head_block" =~ ^[0-9]+$ ]]; then
        echo "haf_block_log holds no blocks; refusing to serve it" >&2
        exit 1
    fi
    # A template left by an interrupted freeze has no row: start it over.
    psql_pg -d postgres <<'EOF'
select 'alter database haf_template is_template false' where exists (select 1 from pg_database where datname = 'haf_template')
\gexec
EOF
    psql_pg -d postgres -c 'drop database if exists haf_template'
    psql_pg -d postgres -c 'create database haf_template template haf_block_log strategy file_copy'
    psql_pg -d postgres -c 'alter database haf_template is_template true allow_connections false'
    psql_pg -d haf_shared -v commit="$commit" -v head_block="$head_block" <<'EOF'
insert into haf_shared.template (database_name, haf_commit, head_block) values ('haf_template', :'commit', :'head_block');
EOF
fi
psql_pg -d haf_shared -c 'select * from haf_shared.health()'

reap() {
    while sleep "$interval"; do
        psql_pg -d haf_shared -At -v ttl="$ttl" <<'EOF' || echo "reaping run databases failed; retrying in ${interval}s" >&2
select 'reaped ' || haf_shared.reap_run_databases(:'ttl');
EOF
    done
}
reap &

exec "$HAF_SOURCE_DIR/scripts/maintenance-scripts/sleep_infinity.sh"
