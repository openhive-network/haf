#!/bin/bash

# Generate pg_hba.conf from the PG_ACCESS environment variable.
# Defaults allow local trust authentication and Docker network access.

PG_ACCESS="${PG_ACCESS:-host    haf_block_log     haf_app_admin    172.0.0.0/8    trust\nhost    all     pghero    172.0.0.0/8    trust}"

HBA_FILE="$PGDATA/pg_hba.conf"

cat > "$HBA_FILE" <<'EOF'
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Trust local connections (Unix socket)
local   all             all                                     trust

# Trust IPv4 local connections
host    all             all             127.0.0.1/32            trust

# Trust IPv6 local connections
host    all             all             ::1/128                 trust

# Allow all connections from Docker networks (configurable via PG_ACCESS)
EOF

echo -e "$PG_ACCESS" >> "$HBA_FILE"

# Append any PG_ACCESS_* environment variables (PG_ACCESS_1, PG_ACCESS_2, etc.)
for var in $(compgen -e | grep '^PG_ACCESS_' | sort); do
  echo -e "${!var}" >> "$HBA_FILE"
done

echo "pg_hba.conf generated:"
cat "$HBA_FILE"
