#!/usr/bin/env bash

BUILD_DIR=.
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir

# Array of noncontiguous numbers
NUMBERS=(1  300000 450000)


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

    # Optionally, remove the log file after stopping hived
    rm "$LOG_FILE"
}

# Loop over the array of noncontiguous numbers
for LAST_BLOCK in "${NUMBERS[@]}"
do
    echo "Running with LAST_BLOCK set to $LAST_BLOCK"
    run_hived_and_monitor $LAST_BLOCK
done
