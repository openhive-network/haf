#!/bin/bash

# Helper script associated with the test `/haf/tests/integration/test_double_haf_replay.sh`

set -xeuo pipefail

LOG_FILE="${DATADIR}/${LOG_FILE:-psql.log}"
sudo -n touch $LOG_FILE
sudo -n chown -Rc hived:users $LOG_FILE
sudo -n chmod a+rw "$LOG_FILE"

POSTGRESLOG=$(find /var/log -name postgresql*.log) || true
echo $POSTGRESLOG || true
sudo ls -lah $POSTGRESLOG || true
echo "mtlk Listing 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing postgres log"

# credits: https://stackoverflow.com/a/39028690/11738218
RETRIES=12
until psql -d haf_block_log -c "SELECT 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "Waiting for postgres server, $((RETRIES--)) remaining attempts..."
  sleep 10
done

POSTGRESLOG=$(find / -name postgresql*.log) || true
echo $POSTGRESLOG || true
sudo ls -lah $POSTGRESLOG || true
echo "mtlk Listing 10 000 last lines of postgres log"
sudo tail -n 10000 $POSTGRESLOG
echo "mtlk end listing postgres log"

echo "CHECK NUMBER OF REPLAYED BLOCKS"
psql -d haf_block_log -c 'select count (*) from hive.blocks' 2>&1 | tee -i ${LOG_FILE}

