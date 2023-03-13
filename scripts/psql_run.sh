#!/bin/bash

set -xeuo pipefail

LOG_FILE="${DATADIR}/${LOG_FILE:-psql.log}"
sudo -n touch $LOG_FILE
sudo -n chown -Rc hived:users $LOG_FILE
sudo -n chmod a+rw "$LOG_FILE"

sudo -n /etc/init.d/postgresql restart

echo "CHECK NUMBER OF REPLAYED BLOCKS"
psql -d haf_block_log -c 'select count (*) from hive.blocks' 2>&1 | tee -i ${LOG_FILE}

