#!/bin/bash
# Schedule HAF cron jobs idempotently.
# The cron_jobs.sql file is copied into this directory at build time.
# We unschedule existing jobs first to avoid duplicates on restart.
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"

psql -U haf_maintainer -d haf_block_log <<'EOF'
-- Remove existing jobs to avoid duplicates
SELECT cron.unschedule(jobname) FROM cron.job WHERE jobname IN ('dead_app_contexts_auto_detach', 'delete-job-run-details');
EOF

psql -U haf_maintainer -d haf_block_log -f "$SCRIPT_DIR/cron_jobs.dat"
