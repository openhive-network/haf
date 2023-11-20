#!/usr/bin/env bash

BUILD_DIR=.
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir

# Array of noncontiguous numbers
NUMBERS=(1   450000)


fetch_and_display_account_names() {
    local start_account=""
    local limit=10
    local result_file="/tmp/account_names.txt"
    local total_accounts_fetched=0  # Initialize the cumulative counter
    > "$result_file" # Clear the file at the beginning

    while true; do
        # Fetch account names starting from the last fetched account
        response=$(curl -s --data '{"jsonrpc":"2.0", "method":"database_api.list_accounts", "params": {"start":"'"$start_account"'", "limit":'"$limit"', "order":"by_name"}, "id":1}' localhost:8090)
        accounts=$(echo "$response" | jq -r '.result.accounts')
        accounts_fetched=$(echo "$accounts" | jq -r '.[].name')
        echo "$accounts_fetched" >> "$result_file"

        # Determine the number of accounts fetched
        num_accounts_fetched=$(echo "$accounts" | jq length)
        total_accounts_fetched=$((total_accounts_fetched + num_accounts_fetched))



        # Check if the fetched batch is less than the limit or empty
        num_accounts_fetched=$(echo "$accounts" | jq length)
        if [ "$num_accounts_fetched" -lt "$limit" ] || [ -z "$accounts_fetched" ]; then
            break
        fi

        # Get the last account name for the next iteration
        start_account=$(echo "$accounts" | jq -r '.[-1].name')
    done

    # Display the collected account names
    # cat "$result_file"

    # Count the number of accounts
    local account_count=$(wc -l < "$result_file")
    echo "Number of accounts fetched: $account_count"

    echo "Cumulative total number of accounts fetched: $total_accounts_fetched"

}

# haf_stuff()
# {
#     psql -d haf_block_log -c "SELECT mmm.main_test('mmm',1, 12000000,10000);" > main_test.log 2>&1
# }

# Function to start hived and monitor its stderr
run_hived_and_monitor() {
    LAST_BLOCK=$1
    LOG_FILE="/tmp/hived_stderr_${LAST_BLOCK}.log"
    FORCE_REPLAY_OPTION=""

    # Apply --force-replay only on the first iteration
    if [ "$LAST_BLOCK" -eq ${NUMBERS[0]} ]; then
        FORCE_REPLAY_OPTION="--force-replay"
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
        --plugin=sql_serializer \
        --psql-url=dbname=haf_block_log host=/var/run/postgresql port=5432 \
    2> >(tee "$LOG_FILE") &

    PID=$!
    echo "Started hived with PID: $PID"

    # Monitor the stderr log of hived
    while true; do
        if grep -q "P2P plugin startup..." "$LOG_FILE"; then

            echo "Running hived (PID: $PID) (block_num: $LAST_BLOCK)"
            curl -s --data '{"jsonrpc":"2.0", "method":"condenser_api.get_account_count", "params":[], "id":1}' localhost:8090 | jq .
            fetch_and_display_account_names            
            echo "Stopping hived (PID: $PID)"
            kill -SIGINT $PID
            break
        fi
        sleep 1
    done


    psql -d haf_block_log -c "SELECT mmm.main_test('mmm',1, $LAST_BLOCK,10000);" 
    psql -d haf_block_log -c "\d"
    psql -d haf_block_log -c "table contexts"
    psql -d haf_block_log -c "table mmm_accountauth_a"
    


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

apply_keyauth

# Loop over the array of noncontiguous numbers
for LAST_BLOCK in "${NUMBERS[@]}"
do
    echo "Running with LAST_BLOCK set to $LAST_BLOCK"
    run_hived_and_monitor $LAST_BLOCK
done

drop_keyauth