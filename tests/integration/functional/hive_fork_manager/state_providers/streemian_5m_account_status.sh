#!/usr/bin/env bash

BUILD_DIR=.
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir

# Array of noncontiguous numbers

NUMBERS=(

3410411
3410412
3410413
3410414
3410415
3410416
3410417
3410418
3410419

#    1606720
#    1606720
#    1606743
#    1606803
#    1669442
#    1669442
#    1674430
#    1674430
#    1699952
#    1699957
#    1699957
#    1700415
#    1700415
#    1700529
#    1700529
#    1701809
#    1701809
#    1701833
#    1701833
#    1701839
#    1701851
#    1701851
#    1701720
#    1701723
#    1701723
#    1701734
#    1701734
#    1701736
#    1701736
#    1701743
#    1701743
#    1701755
#    1701765
#    1701765
#    1701768
#    1701768
#    1701775
#    1701775
#    1701864
#    1701864
#    1701905
#    1701905
#    1701917
#    1701917
#    1701929
#    1701929
#    1701931
#    1701931
#    1701976
#    1701976
#    1702204
#    1702204
#    1702029
#    1702029
#    1702064
#    1702450
#    1702450
#    1702468
#    1702468
#    1702500
#    1702500
#    1702506
#    1702506
#    1702542
#    1702542
#    1702966
#    1703210
#    1703210
#    1703169
#    1703326
#    1703326
#    1703591
#    1703591
#    1704852
#    1704852
#    1704953
#    1704953
#    1704763
#    1704661
#    1704661
#    1705028
#    1705028
#    1717756
#    1717756
#    1718390
#    1718390
#    1719603
#    1719458
#    1719458
#    1719499
#    1719536
#    1719536
#    1719962
#    1720207
#    1720207
#    1721922
#    1721922
#    1722892
#    1722990
#    1723975
#    1724090
#    1724090
#    1724259
#    1724259
#    1724873
#    1724873
#    1724901
#    1724526
#    1724526
#    1724527
#    1724527
#    1725645
#    1726375
#    1725869
#    1725097
#    1725328
#    1725340
#    1725340
#    1725356
#    1725356
#    1725375
#    1725375
#    1725375
#    1725375
#    1725379
#    1725379
#    1725212
#    1725384
#    1725384
#    1725384
#    1725384
#    1726068
#    1726068
#    1726073
#    1726073
#    1726375
#    1727486
#    1727486
#    1727492
#    1727492
#    1725592
#    1729284
#    1729284
#    1737470
#    1737470
#    1757724
#    1757724
#    1757449
#    1757449
#    1757548
#    1757548
#    1757242
#    1757250
#    1757250
#    1757284
#    1757284
#    1757295
#    1757295
#    1757303
#    1757303
#    1757309
#    1757309
#    1757907
#    1757907
#    1757940
#    1757940
#    1758324
#    1758324
#    1759388
#    1759351
#    1759351
#    1761426
#    1761426
#    1761647
#    1761647
#    1761525
#    1761525
#    1758891
#    1758891
#    1762644
#    1762613
#    1765460
#    1765460
#    1767712
#    1767712
#    1778273
#    1778273
#    1789602
#    1789602
#    1789627
#    1789627
#    1789629
#    1789720
#    1789288
#    1789368
#    1789368
#    1789527
#    1790101
#    1790101
#    1796310
#    1796310
#    1803037
#    1803037
#    1808441
#    1808507
#    1808534
#    1809288
#    1809337
#    1810916
#    1810916
#    1810491
#    1810496
#    1810496
#    1812512
#    1812512
#    1813871
#    1813871
#    1813705
#    1813705
#    1815787
#    1815787
#    1816025
#    1816025
#    1816163
#    1816163
#    1816170
#    1816170
#    1817287
#    1817287
#    1817287
#    1817287
#    1817292
#    1817292
#    1822353
#    1822353
#    1826849
#    1836855
#    1839634
#    1839665
#    1839696
#    1839729
#    1839859
#    1839859
#    1840556
#    1840556
#    1841765
#    1841765
#    1840777
#    1841700
#    1842651
#    1843706
#    1843706
#    1843708
#    1843708
#    1843718
#    1843718
#    1844567
#    1844567
#    1848981
#    1848981
#    1868167
#    1868167
#    1872740
#    1872740
#    1881176
#    1881176
#    1924433
#    1924471
#    1926101
#    1926101
#    1956462
#    1956483
#    1957217
#    1957217
#    1957277
#    1958200
#    1958200
#    1957820
#    1957822
#    1957822
#    1957778
#    1957082
#    1957842
#    1957877
#    1957877
#    1957878
#    1957897
#    1957897
#    1957905
#    1957945
#    1957945
#    1957950
#    1957950
#    1957965
#    1957986
#    1957986
#    1958668
#    1958668
#    1958712
#    1958712
#    1958812
#    1958812
#    1958432
#    1958432
#    1958448
#    1958448
#    1958015
#    1958015
#    1958280
#    1958280
#    1958280
#    1958057
#    1958057
#    1960217
#    1958556
#    1958556
#    1958322
#    1958593
#    1958593
#    1958098
#    1958098
#    1958396
#    1958144
#    1958144
#    1958159
#    1958159
#    1958178
#    1958178
#    1959055
#    1959055
#    1959113
#    1959113
#    1959142
#    1959142
#    1959172
#    1959406
#    1959406
#    1959406
#    1959406
#    1959407
#    1959407
#    1959409
#    1959409
#    1959409
#    1959409
#    1959557
#    1959557
#    1959582
#    1959892
#    1959892
#    1958245
#    1958245
#    1958257
#    1958257
#    1960343
#    1960507
#    1960507
#    1960109
#    1960532
#    1960532
#    1961034
#    1961034
#    1960592
#    1961836
#    1961358
#    1961624
#    1961624
#    1961836
#    1961928
#    1961928
#    1961501
#    1961501
#    1961988
#    1961988
#    1961164
#    1961164
#    1961176
#    1962116
#    1962126
#    1962126
#    1962231
#    1962231
#    1962311
#    1962759
#    1962759
#    1963818
#    1963868
#    1964424
#    1964424
#    1964463
#    1964463
#    1964206
#    1964206
#    1964216
#    1964216
#    1964854
#    1964854
#    1964855
#    1964855
#    1964110
#    1964110
#    1964303
#    1964303
#    1964999
#    1964355
#    1964355
#    1965152
#    1965152
#    1968918
#    1968918
#    1970019
#    1970019
#    1973649
#    1973649
#    1978480
#    1978480
#    1979725
#    1979820
#    1980893
#    1981671
#    1982053
#    1981485
#    1981570
#    1982319
#    1982319
#    1982120
#    1982909
#    1982909
#    1982739
#    1983123
#    1984856
#    1984877
#    1983291
#    1983291
#    1985035
#    1985215
#    1985987
#    1985987
#    1985992
#    1985992
#    1986837
#    1986837
#    1986669
#    1987260
#    1987709
#    1987660
#    1987661
#    1987661
#    1987480
#    1988596
#    1988270
#    1988930
#    1988950
#    1988950
#    1989010
#    1989031
#    1989039
#    1989403
#    1988815
#    1989594
#    1989594
#    1989499
#    1989522
#    1989522
#    1989716
#    1990634
#    1990634
#    1989884
#    1989921
#    1991628
#    1991335
#    1991336
#    1991336
#    1991224
#    1991526
#    1991594
#    1991594
#    1991603
#    1991603
#    1991043
#    1992714
#    1992714
#    1991370
#    1991370
#    1994456
#    1994456
#    1994459
#    1994459
#    1994334
#    1994334
#    1996563
#    1996563
#    1997329
#    1997329
#    1997972
#    1997972
#    1997090
#    1997090
#    1997095
#    1997095
#    1998851
#    1998851
#    2017453
#    2017453
#    2033605
#    2033605
#    2040349
#    2040349
#    2056956
#    2056956
#    2073873
#    2073873
#    2073883
#    2073883
#    2073935
#    2073935
#    2073767
#    2073767
#    2073789
#    2073789
#    2140820
#    2140820
#    2140695
#    2140695
#    2297568
#    2297568
#    2383264
#    2383264

)
# NUMBERS=(1 2794855 2794856 5000000)

fetch_and_save_streemian_account() {
    local last_block=$1
    local result_file="/tmp/a_streemian_changes.txt"
    local account_file="/tmp/streemian_$last_block.json"

    # Fetch 'streemian' account data
    response=$(curl -s --data '{"jsonrpc":"2.0", "method":"condenser_api.get_accounts", "params":[["streemian"]], "id":1}' localhost:8090)
    account_data=$(echo "$response" | jq -r '.result[0]')

    # Save the account data to a file named "streemian_block_number"
    echo "$account_data" > "$account_file"

    # Check for changes in the account data and log to result_file
    if [ "$previous_account_data" != "$account_data" ]; then
        if [ -n "$previous_account_data" ]; then
            echo "Change detected at block $last_block" >> "$result_file"
            echo "Account data saved in $account_file" >> "$result_file"
        fi
        previous_account_data="$account_data"
    fi
}

previous_data=""

# Function to fetch and monitor changes in the 'streemian' account

fetch_and_monitor_streemian() {
    local last_block=$1
    local result_file="/tmp/streemian_changes.txt"

    # Fetch 'streemian' account data
    response=$(curl -s --data '{"jsonrpc":"2.0", "method":"condenser_api.get_accounts", "params":[["streemian"]], "id":1}' localhost:8090)
    current_owner_account_auths=$(echo "$response" | jq -r '.result[0].owner.account_auths')
    current_active_account_auths=$(echo "$response" | jq -r '.result[0].active.account_auths')
    current_posting_account_auths=$(echo "$response" | jq -r '.result[0].posting.account_auths')
    current_owner_key_auths=$(echo "$response" | jq -r '.result[0].owner.key_auths')
    current_active_key_auths=$(echo "$response" | jq -r '.result[0].active.key_auths')
    current_posting_key_auths=$(echo "$response" | jq -r '.result[0].posting.key_auths')
    current_memo_key=$(echo "$response" | jq -r '.result[0].memo_key')

    # Check for changes in each field
    if [ "$current_owner_account_auths" != "$previous_owner_account_auths" ] || [ "$current_active_account_auths" != "$previous_active_account_auths" ] || [ "$current_posting_account_auths" != "$previous_posting_account_auths" ] || [ "$current_owner_key_auths" != "$previous_owner_key_auths" ] || [ "$current_active_key_auths" != "$previous_active_key_auths" ] || [ "$current_posting_key_auths" != "$previous_posting_key_auths" ] || [ "$current_memo_key" != "$previous_memo_key" ]; then
        echo "Change detected at block $last_block" >> "$result_file"
        echo "owner.account_auths: $current_owner_account_auths" >> "$result_file"
        echo "active.account_auths: $current_active_account_auths" >> "$result_file"
        echo "posting.account_auths: $current_posting_account_auths" >> "$result_file"
        echo "owner.key_auths: $current_owner_key_auths" >> "$result_file"
        echo "active.key_auths: $current_active_key_auths" >> "$result_file"
        echo "posting.key_auths: $current_posting_key_auths" >> "$result_file"
        echo "memo_key: $current_memo_key" >> "$result_file"
    fi

    # Update previous data variables
    previous_owner_account_auths="$current_owner_account_auths"
    previous_active_account_auths="$current_active_account_auths"
    previous_posting_account_auths="$current_posting_account_auths"
    previous_owner_key_auths="$current_owner_key_auths"
    previous_active_key_auths="$current_active_key_auths"
    previous_posting_key_auths="$current_posting_key_auths"
    previous_memo_key="$current_memo_key"
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
            fetch_and_monitor_streemian $LAST_BLOCK
            fetch_and_save_streemian_account $LAST_BLOCK
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