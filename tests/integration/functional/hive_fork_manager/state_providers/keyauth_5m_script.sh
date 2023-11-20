#!/usr/bin/env bash



BUILD_DIR=.
# BUILD_DIR=/home/haf_admin/playground/haf.worktrees/keyauth/build
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir



# Array of noncontiguous numbers
NUMBERS=(1 450000)
#NUMBERS=(1 5000 20000 37000 58000 91000 150000 300000 450000)

RESULT_FILE=result.json
echo '' > $RESULT_FILE

#!/usr/bin/env bash

# ... [rest of your script] ...

# Function to fetch and display account names
fetch_and_display_account_names() {
    local start_account=""
    local limit=10
    local result_file="/tmp/account_names.txt"

    for ((i=0; i<10; i++)); do
        # Fetch account names starting from the last fetched account
        response=$(curl -s --data '{"jsonrpc":"2.0", "method":"database_api.list_accounts", "params": {"start":"'"$start_account"'", "limit":'"$limit"', "order":"by_name"}, "id":1}' localhost:8090)
        echo "$response" | jq '.result.accounts[].name' >> "$result_file"

        # Get the last account name for the next iteration
        start_account=$(echo "$response" | jq -r '.result.accounts[-1].name')

        # Optional: Break if there are no more accounts to fetch
        if [ -z "$start_account" ]; then
            break
        fi
    done

    # Display the collected account names
    cat "$result_file"
}

# and monitor its stderr
run_hived_and_monitor() {
    LAST_BLOCK=$1
    LOG_FILE="${LAST_BLOCK}.log"

    echo LOG_FILE $LOG_FILE

    FORCE_REPLAY_OPTION=""

    # Apply --force-replay only on the first iteration
    if [ "$LAST_BLOCK" -eq 1 ]; then
        FORCE_REPLAY_OPTION="--force-replay"
    fi

    # Start hived and redirect its stderr to a log file
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
            
            echo Processing block_num $LAST_BLOCK

            curl -s --data '{"jsonrpc":"2.0", "method":"condenser_api.get_account_count", "params":[], "id":1}' localhost:8090 | jq .  
            fetch_and_display_account_names

            echo "Stopping hived (PID: $PID)"
            sleep 1
            
            kill -SIGINT $PID
            break
        fi
        sleep 1
    done

    # Optionally, remove the log file after stopping hived
    # rm "$LOG_FILE"
}


for LAST_BLOCK in "${NUMBERS[@]}"
do
    echo "Running with LAST_BLOCK set to $LAST_BLOCK"
    run_hived_and_monitor $LAST_BLOCK
done

