#!/bin/bash

# we are in build directory

# mtlk TODO
# start/stop on contextual shared mem file
# What about ON CONFLICT DO NOTHING in src/hive_fork_manager/state_providers/current_account_balance.sql - two accounts in one state ?     texcik = format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances_C(%L) ON CONFLICT DO NOTHING;', __table_name, _context);

set -ex

SERIALIZE_TILL_BLOCK=100000

RUN_MINIMAL_TILL_BLOCK=1000
RUN_MINIMAL_CONT_TILL_BLOCK=5000

RUN_APP_MAIN_TILL_BLOCK=2000
RUN_APP_MAIN_CHUNK_SIZE=1000

RUN_APP_CONT_MAIN_TILL_BLOCK=8000
RUN_APP_CONT_MAIN_CHUNK_SIZE=1000

BUILD_DIR=.
SRC_DIR=../haf
DATA_DIR=/home/dev/mainnet-5m



killpostgres()
{
    sudo killall -9 postgres || true
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

remove_all_compiled()
{
    remove_compiled
    rm -rf $BUILD_DIR/*
    rm -rf $BUILD_DIR/.* | true
}   

build()
{
if [[ "$PWD" =~ build$ ]]
then

    # cmake  -DCMAKE_BUILD_TYPE=Release -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-fdiagnostics-color=always" -GNinja $SRC_DIR ;  # Release
    cmake  -DCMAKE_BUILD_TYPE=Debug -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-O0 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # Debug O0
    # cmake  -DCMAKE_BUILD_TYPE=Debug -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-O2 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # Debug O2

    (ninja  hived extension.hive_fork_manager  && sudo ninja install && sudo chown $USER:$USER .ninja_* && ctest -R keyauth --output-on-failure) ; 
else
    echo "NOT in build directory!!!"
fi

}

serializer()
{
    $BUILD_DIR/hive/programs/hived/hived --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --plugin=sql_serializer --psql-url=dbname=haf_block_log host=/var/run/postgresql port=5432 --replay --exit-before-sync --stop-replay-at-block=$SERIALIZE_TILL_BLOCK --force-replay # serializer
}

minimal_hived()
{
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    $BUILD_DIR/hive/programs/hived/hived --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --replay --exit-before-sync --stop-replay-at-block=$RUN_MINIMAL_TILL_BLOCK --force-replay # minimal
else
    $BUILD_DIR/hive/programs/hived/hived --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --replay --exit-before-sync --stop-replay-at-block=${1} --force-replay # minimal

fi

}

minimal_hived_cont()
{
    $BUILD_DIR/hive/programs/hived/hived --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --replay --exit-before-sync --stop-replay-at-block=$RUN_MINIMAL_CONT_TILL_BLOCK # minimal cont
}

app_start()
{
    rm -f  ~/mainnet-5m/blockchain/keyauth_appshared_memory.bin 

    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c "select hive.app_reset_data('keyauth_app');" && psql -v "ON_ERROR_STOP=1" -d haf_block_log -f $SRC_DIR/src/hive_fork_manager/state_providers/performance_examination/keyauth_app.sql &&  psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing'  -c "call keyauth_app.main('keyauth_app', $RUN_APP_MAIN_TILL_BLOCK, $RUN_APP_MAIN_CHUNK_SIZE)" -c 'select * from hive.keyauth_app_current_account_balance limit 30;' -c 'select count(*) from hive.keyauth_app_accounts;' 2>&1 | tee -i app.log # run
}

app_cont()
{
    permissions
    
    psql -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing' \
    -c "call keyauth_app.main('keyauth_app', $RUN_APP_CONT_MAIN_TILL_BLOCK, $RUN_APP_CONT_MAIN_CHUNK_SIZE)" \
    -c 'select * from hive.keyauth_app_current_account_balance limit 30;' -c 'select count(*) from hive.keyauth_app_accounts;' \
    2>&1 | tee -i app.log # run
}



permissions()
{
    chmod 777 /home/dev/mainnet-5m/blockchain/shared_memory.bin || true
    chmod 777 $DATA_DIR/blockchain
    sudo chmod 777 $DATA_DIR/blockchain/*

}


sudo_enter()
{
    sudo echo sudo_enter
}


rebuild_all()
{
    remove_all_compiled
    build
}


rebuild()
{
    remove_compiled
    build
}


run_from_saved()
{
    remove_compiled
    build

    sudo rm -rf $DATA_DIR/blockchain
    cp -r $DATA_DIR/blockchain_$1 $DATA_DIR/blockchain

    chmod 777 $DATA_DIR/blockchain
    chmod 777 $DATA_DIR/blockchain/*

    app
}

# save_state(name, block_num)
save_state()
{
    minimal_hived $2
    cp -ir $DATA_DIR/blockchain $DATA_DIR/blockchain_$1

    #permissions
}

# s->ave blockchain, permissions, app

# # minimal_hived_cont
# # minimal_hived
# # permissions

# ->deleterestore blockchain, app


run_all_from_scratch()
{
    sudo_enter
    killpostgres
    erase_haf_block_log_database
    reset_app
    remove_compiled
    build
    
    #what about blockchain dir - erase?
    permissions
    
    serializer
    # minimal_hived
    #permissions
    app_start
}

# # # run_from_saved

# # # save_state sav3M5 3500000
# # # save_state sav1M 1000000

# # save_state sav4M9Rel
# # # run_from_saved sav3M5Rel


# # run_all_from_scratch


# rebuild
# app
echo ">>>>>>Invoking $1 <<<<<<<<"
$1