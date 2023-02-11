#!/bin/bash

# we are in build directory

set -ex

SERIALIZE_TILL_BLOCK=3'000'000
RUN_MINIMAL_TILL_BLOCK=2'726'329
RUN_MAIN_TILL_BLOCK=3000000
RUN_MAIN_CHUNK_SIZE=10000

BUILD_DIR=.
SRC_DIR=../haf
DATA_DIR=/home/dev/mainnet-5m



killpostgres()
{
    sudo killall -9 postgres;
    sudo systemctl restart postgresql;
    return 0;
}

erase_haf_block_log_database()
{
    sudo $SRC_DIR/scripts/setup_db.sh || true # erase haf_block_log database
}

reset_app()
{
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c "select hive.app_reset_data('keyauth_app');" || true # reset app
}


remove_compiled()
{
    rm -rf $BUILD_DIR/extensions/hive_fork_manager || true ; sudo rm /usr/share/postgresql/12/extension/hive* || true;    sudo rm /usr/lib/postgresql/12/lib/libhfm* || true; 
}

build()
{

    # cmake  -DCMAKE_BUILD_TYPE=Release -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-fdiagnostics-color=always" -GNinja .. ;  # Release

    cmake  -DCMAKE_BUILD_TYPE=Debug -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-O0 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # Debug O0
    (ninja  hived extension.hive_fork_manager  && sudo ninja install && sudo chown $USER:$USER .ninja_* && ctest -R keyauth --output-on-failure) ; 
}

serializer()
{
    $BUILD_DIR/hive/programs/hived/hived --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --plugin=sql_serializer --psql-url=dbname=haf_block_log host=/var/run/postgresql port=5432 --replay --exit-before-sync --stop-replay-at-block=$SERIALIZE_TILL_BLOCK --force-replay # serializer
}

minimal_hived()
{
    $BUILD_DIR/hive/programs/hived/hived --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --replay --exit-before-sync --stop-replay-at-block=$RUN_MINIMAL_TILL_BLOCK --force-replay # minimal
}

minimal_hived_cont()
{
    $BUILD_DIR/hive/programs/hived/hived --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --replay --exit-before-sync --stop-replay-at-block=102 # minimal cont
}

app()
{
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c "select hive.app_reset_data('keyauth_app');" && psql -v "ON_ERROR_STOP=1" -d haf_block_log -f /home/dev/mydes/H/haf/src/hive_fork_manager/state_providers/performance_examination/keyauth_app.sql &&  psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing'  -c "call keyauth_app.main('keyauth_app', $RUN_MAIN_TILL_BLOCK, $RUN_MAIN_CHUNK_SIZE)" -c 'select * from hive.keyauth_app_current_account_balance;' -c 'select count(*) from hive.keyauth_app_accounts;' 2>&1 | tee -i app.log # run
}



permissions()
{
    chmod 777 /home/dev/mainnet-5m/blockchain/shared_memory.bin
}


sudo_enter()
{
    sudo echo sudo_enter
}

sudo_enter
killpostgres
erase_haf_block_log_database
reset_app
remove_compiled
build
serializer
minimal_hived
permissions
# minimal_hived_cont
# minimal_hived
# permissions


app
