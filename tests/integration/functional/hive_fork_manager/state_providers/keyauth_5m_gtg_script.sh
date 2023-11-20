#!/usr/bin/env bash

BUILD_DIR=.
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir

# Array of noncontiguous numbers

NUMBERS=(1 2794856
2796791
2797050
2797188
5000000)
# NUMBERS=(1 2794855 2794856 5000000)


previous_data=""

# Function to fetch and monitor changes in the 'gtg' account
fetch_and_monitor_gtg() {
    local last_block=$1
    local result_file="/tmp/gtg_changes.txt"

    # Fetch 'gtg' account data
    response=$(curl -s --data '{"jsonrpc":"2.0", "method":"condenser_api.get_accounts", "params":[["gtg"]], "id":1}' localhost:8090)
    current_data=$(echo "$response" | jq -r '.result[0]')

    # Log for debugging
    echo "Fetched data for block $last_block" >> "$result_file"

    if [ "$current_data" != "$previous_data" ]; then
        echo "Change detected at block $last_block" >> "$result_file"
        echo "$current_data" >> "$result_file"
        previous_data="$current_data"
    fi
}

g_is_first_run=1
# Function to start hived and monitor its stderr
run_hived_and_monitor() {
    LAST_BLOCK=$1
    LOG_FILE="/tmp/hived_stderr_${LAST_BLOCK}.log"
    FORCE_REPLAY_OPTION=""

    # Apply --force-replay only on the first iteration
    if [ "$g_is_first_run" -eq 1 ]; then
        FORCE_REPLAY_OPTION="--force-replay"
        g_is_first_run=0

    fi

    # Start hived with the conditional --force-replay option


    $BUILD_DIR/hive/programs/hived/hived \
        --webserver-ws-endpoint=0.0.0.0:8091 \
        --webserver-http-endpoint=0.0.0.0:8090 \
        --data-dir=$DATA_DIR \
        --plugin=condenser_api \
        --plugin=block_api \
        $FORCE_REPLAY_OPTION \
        --replay \
        --stop-replay-at-block=$LAST_BLOCK \
        --shared-file-dir=$DATA_DIR/blockchain \
    2> >(tee "$LOG_FILE") &
    # 2> "$LOG_FILE" &

    PID=$!
    echo "Started hived with PID: $PID"

    # Monitor the stderr log of hived
    while true; do
        if grep -q "P2P plugin startup..." "$LOG_FILE"; then

            echo "Running hived (PID: $PID) (block_num: $LAST_BLOCK)"
            curl -s --data '{"jsonrpc":"2.0", "method":"condenser_api.get_account_count", "params":[], "id":1}' localhost:8090 | jq .
            fetch_and_monitor_gtg $LAST_BLOCK
            echo "Stopping hived (PID: $PID)"
            kill -SIGINT $PID
            break
        fi
        sleep 1
    done


    # psql -d haf_block_log -c "SELECT mmm.main_test('mmm',1, $LAST_BLOCK,10000);" 

    # psql -d haf_block_log -c "\pset pager off"
    # psql -d haf_block_log -c "table hive.contexts"
    # psql -d haf_block_log -c "table hive.mmm_accountauth_a"
    # psql -d haf_block_log -c "table hive.mmm_keyauth_a"
    # psql -d haf_block_log -c "table hive.mmm_keyauth_k"


    # Optionally, remove the log file after stopping hived
    rm "$LOG_FILE"
}

apply_keyauth()
{
SQL_COMMANDS="
CREATE SCHEMA IF NOT EXISTS mmm;
SELECT hive.app_create_context('mmm');
SELECT hive.app_state_provider_import('KEYAUTH', 'mmm');
SELECT hive.app_context_detach('mmm');

CREATE OR REPLACE FUNCTION mmm.main_test(
    IN _appContext VARCHAR,
    IN _from INT,
    IN _to INT,
    IN _step INT
)
RETURNS void
LANGUAGE 'plpgsql'

AS
\$\$
DECLARE
_last_block INT ;
BEGIN

  FOR b IN _from .. _to BY _step LOOP
    _last_block := b + _step - 1;

    IF _last_block > _to THEN --- in case the _step is larger than range length
      _last_block := _to;
    END IF;

    RAISE NOTICE 'Attempting to process a block range: <%s, %s>', b, _last_block;

    PERFORM hive.app_state_providers_update(b, _last_block, _appContext);

    RAISE NOTICE 'Block range: <%s, %s> processed successfully.', b, _last_block;

  END LOOP;

  RAISE NOTICE 'Leaving massive processing of block range: <%s, %s>...', _from, _to;
END
\$\$;
"
    psql -d haf_block_log -c "$SQL_COMMANDS"

}

drop_keyauth()
{
SQL_COMMANDS="
SELECT hive.app_state_provider_drop('KEYAUTH', 'mmm');
SELECT hive.app_remove_context('mmm');
"
    psql -d haf_block_log -c "$SQL_COMMANDS"

}

# apply_keyauth

# Loop over the array of noncontiguous numbers
for LAST_BLOCK in "${NUMBERS[@]}"
do
    echo "Running with LAST_BLOCK set to $LAST_BLOCK"
    run_hived_and_monitor $LAST_BLOCK
done

# drop_keyauth