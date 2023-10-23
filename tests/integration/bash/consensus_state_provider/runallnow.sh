#! /usr/bin/env bash
set -x
set -euo pipefail

BEFORE_HF26=68676505
BEFORE_PROBLEM=23645964
BIG=73964098
MILLIONS_5=5000000
MILLION_1=1000000
THOUSAND_1=1000
THOUSAND_2=2000
THOUSAND_3=3000


if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    exit 1
fi


LAST_BLOCK=$MILLIONS_5
if  [ $1 -eq $1 ] 2>/dev/null; then
    #The param is a number, so  it is last block
    LAST_BLOCK=$1
    shift
fi

SERIALIZE_TILL_BLOCK=$LAST_BLOCK
NO_SERIALIZE_TILL_BLOCK=$SERIALIZE_TILL_BLOCK

RUN_MINIMAL_TILL_BLOCK=1000
RUN_MINIMAL_CONT_TILL_BLOCK=5000

RUN_APP_MAIN_TILL_BLOCK=2000
RUN_APP_MAIN_CHUNK_SIZE=1000

RUN_APP_CONT_MAIN_TILL_BLOCK=$LAST_BLOCK
RUN_APP_CONT_MAIN_CHUNK_SIZE=$(expr $RUN_APP_CONT_MAIN_TILL_BLOCK / 50)

BUILD_DIR=.
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir


if [ -z ${CI+x} ]
then
    echo NOt In CI
    CONSENSUS_STORAGE=$DATA_DIR/consensus_state_provider
else
    echo In CI
    CONSENSUS_STORAGE=$PATTERNS_PATH/consensus_state_provider
fi

echo $CONSENSUS_STORAGE

if [ -z ${USER+x} ]
then
    echo NO USER variable
    USER=$(whoami)
fi

killpostgres()
{
    # sudo killall -9 postgres || true

    if $(systemctl list-machines)
    then
        sudo systemctl restart postgresql;
    else
        sudo -n /etc/init.d/postgresql restart
    fi
    return 0;
}

erase_haf_block_log_database()
{
    sudo $SRC_DIR/scripts/setup_db.sh || true # erase haf_block_log database
}

reset_app()
{
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c "select hive.app_reset_data('cabc');" || true # reset app
}


remove_compiled()
{
    rm -rf $BUILD_DIR/extensions/hive_fork_manager || true ;
    sudo rm /usr/share/postgresql/14/extension/hive* || true;
    sudo rm /usr/lib/postgresql/14/lib/libhfm* || true;
    rm -rf $BUILD_DIR/lib/libhfm* || true;
}

remove_all_compiled()
{
    remove_compiled
    rm -rf $BUILD_DIR/*
    rm -rf $BUILD_DIR/.* | true
}

build()
{

local CMAKED=false
local EXIT_STATUS=0

if [[ "$PWD" =~ debug_build$ ]]
then
    cmake  -DCMAKE_BUILD_TYPE=Debug -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS=" -O0 -fdiagnostics-color=always -Werror=return-type" -GNinja $SRC_DIR ; # Debug O0

    CMAKED=true

elif [[ "$PWD" =~ RelWithDebInfo_build$ ]]
then
    echo building RelWithDebInfo
    cmake  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-O0 -fdiagnostics-color=always -Werror=return-type" -GNinja $SRC_DIR ; # RelWithDebInfo

    CMAKED=true

elif [[ "$PWD" =~ testnet_build$ ]]
then
    echo building testnet_build
    cmake  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_HIVE_TESTNET=ON -DCMAKE_CXX_FLAGS="-O0 -fdiagnostics-color=always -Werror=return-type" -GNinja $SRC_DIR ; # testnet_build

    CMAKED=true


elif [[ "$PWD" =~ build$ ]]
then

    cmake  -DCMAKE_BUILD_TYPE=Release -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-fdiagnostics-color=always -Werror=return-type" -GNinja $SRC_DIR ;  # Release


    CMAKED=true

elif [[ "$PWD" =~ Asan$ ]]
then


    cmake  -DCMAKE_BUILD_TYPE=Asan -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-fdiagnostics-color=always" -GNinja $SRC_DIR ;  # Release


    CMAKED=true

else
    echo "NOT in build directory!!!"
fi

if [[ $CMAKED ]]
then
#    ninja extension.hive_fork_manager  \
    ninja tests/unit/all csp_driver query_supervisor hived extension.hive_fork_manager && sudo ninja install && sudo chown $USER:$USER .ninja_* && ctest -R keyauth --output-on-failure && ctest -R curr --output-on-failure
    EXIT_STATUS=$?
    sudo chown -R $USER:$USER *
fi

    return $EXIT_STATUS
}

serializer()
{
    echo "Before serializer"
    time $BUILD_DIR/hive/programs/hived/hived \
    --data-dir=$DATA_DIR \
    --exit-before-sync \
    --force-replay \
    --plugin=sql_serializer \
    --psql-url=dbname=haf_block_log host=/var/run/postgresql port=5432 \
    --replay \
    --shared-file-dir=$DATA_DIR/blockchain \
    --stop-replay-at-block=$SERIALIZE_TILL_BLOCK # serializer
    echo "After serializer"
}

noserializer()
{
    time $BUILD_DIR/hive/programs/hived/hived \
    --blockchain-thread-pool-size=1 \
    --data-dir=$DATA_DIR \
    --exit-before-sync \
    --force-replay \
    --p2p-endpoint=0.0.0.0:2001 \
    --replay \
    --shared-file-dir=$DATA_DIR/blockchain \
    --stop-replay-at-block=$NO_SERIALIZE_TILL_BLOCK \
    --validate-during-replay \
    --webserver-http-endpoint=0.0.0.0:8090 \
    --webserver-ws-endpoint=0.0.0.0:8091 # noserializer
}


naked()
{
    time $BUILD_DIR/hive/programs/hived/hived \
    --blockchain-thread-pool-size=1 \
    --data-dir=$DATA_DIR \
    --force-replay \
    --p2p-endpoint=0.0.0.0:2001 \
    --webserver-http-endpoint=0.0.0.0:8090 \
    --webserver-ws-endpoint=0.0.0.0:8091 # noserializer
}

query_hived()
{

    P2P_PORT=2001
    WS_PORT=8091
    HTTP_PORT=8090




    $BUILD_DIR/hive/programs/hived/hived \
    --webserver-ws-endpoint=0.0.0.0:${WS_PORT} \
    --webserver-http-endpoint=0.0.0.0:${HTTP_PORT} \
    --p2p-endpoint=0.0.0.0:${P2P_PORT} \
    --data-dir=$DATA_DIR \
    --plugin=database_api \
    --replay \
    --force-replay \
    --stop-replay-at-block=1000000
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

    psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c "select * FROM hive.irreversible_data;"
    psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c "select * FROM hive.events_queue;"
    psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c "select * FROM hive.fork;"
    psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c "select * FROM hive.table_schema;"


    rm -f  $DATA_DIR/blockchain/keyauth_appshared_memory.bin
    rm -f  $DATA_DIR/blockchain/cabc_shared_memory.bin
    sudo -u postgres rm -f /var/lib/postgresql/blockchain/*
    sudo rm  /var/lib/postgresql/blockchain/cabc_shared_memory.bin  || true

    psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c "select hive.app_reset_data('cabc');"

    psql -v "ON_ERROR_STOP=1" -d haf_block_log -f $SRC_DIR/tests/integration/bash/consensus_state_provider/consensus_state_provider_app.sql

    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing'  -c "call cab_app.main('cabc', $RUN_APP_MAIN_TILL_BLOCK, $RUN_APP_MAIN_CHUNK_SIZE, '$CONSENSUS_STORAGE')" -c 'select * from hive.cabc_csp LIMIT 30;' -c 'select count(*) from hive.cabc_accounts;' 2>&1 | tee -i app.log # run
}

app_cont()
{
    echo "Before app_cont"
    time psql -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing' \
    -c "call cab_app.main('cabc', $RUN_APP_CONT_MAIN_TILL_BLOCK, $RUN_APP_CONT_MAIN_CHUNK_SIZE, '$CONSENSUS_STORAGE')" \
    -c 'select * from hive.cabc_csp limit 30;' -c 'select count(*) from hive.cabc_accounts;' \
    -c 'select SUM(balance) from hive.cabc_csp' \
    2>&1 | tee -i app.log # run
    echo "After app_cont"

    # Compare if returned 15 top accounts are equal to the pattern
    PSQL_RESULT=$(psql -t -d haf_block_log  -c "(SELECT account, balance, ROW_NUMBER() OVER (ORDER BY balance DESC)  FROM hive.cabc_csp LIMIT 15)
    EXCEPT
    (SELECT p.account, p.balance, p.rownum  FROM  (VALUES
        (1, 'steemit', 4778859891),
        (2, 'poloniex', 1931250425),
        (3, 'bittrex', 499025114),
        (4, 'steemit2', 197446682),
        (5, 'aurel', 97417738),
        (6, 'openledger', 52275479),
        (7, 'ben', 50968139),
        (8, 'blocktrades', 29594875),
        (9, 'steem', 29315310),
        (10, 'imadev', 23787999),
        (11, 'smooth', 20998219),
        (12, 'steemit60', 20000000),
        (13, 'taker', 15014283),
        (14, 'steemit1', 10000205),
        (15, 'ashold882015', 9895158)
                                ) as p(rownum, account, balance)
                                )";)

    echo $PSQL_RESULT
    test "$PSQL_RESULT" = "" && echo ok || echo notok
    test "$PSQL_RESULT" = ""
}



permissions()
{
    chmod 777 $DATA_DIR/blockchain/shared_memory.bin || true
    chmod 777 $DATA_DIR/blockchain || true
    sudo chmod 777 $DATA_DIR/blockchain/* || true


    psql -d haf_block_log  -c 'ALTER DATABASE haf_block_log SET search_path TO hive,public;'

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



remove_context_shared_memory_bin()
{

    sudo rm  -rf $DATA_DIR/consensus_storage
    sudo rm  -rf $DATA_DIR/consensus_state_provider
    sudo rm  $DATA_DIR/context/blockchain/shared_memory.bin && echo removed! || echo not removed
    sudo rm  $DATA_DIR/consensus_state_provider/blockchain/shared_memory.bin && echo removed! || echo not removed

}

run_all_from_scratch()
{
    sudo_enter && \
    killpostgres && \
    erase_haf_block_log_database && \
    reset_app && \
    remove_compiled && \
    build && \
    permissions && #what about blockchain dir - erase? \
    serializer

}

run()
{
    remove_context_shared_memory_bin && run_all_from_scratch && app_start && time app_cont
}

driver_body()
{
    # preconditions for csp_driver
    if [ -d /home/hived/datadir/consensus_state_provider ]
    then
        echo /home/hived/datadir/consensus_state_provider Still there!
    fi

    psql -d haf_block_log -c 'select count(*) from hive.blocks'

    ./bin/csp_driver --to=$LAST_BLOCK

}



driver_clean()
{
    clearterm &&remove_context_shared_memory_bin && run_all_from_scratch &&  driver_body
}


clearterm()
{
    clear && printf '\''\e[3J'\'
}

driver_build()
{
    clearterm &&
    ninja csp_driver query_supervisor hived extension.hive_fork_manager &&
    sudo ninja install &&
    sudo chown $USER:$USER .ninja_* &&
    ctest -R keyauth --output-on-failure
}

driver_build_and_run()
{
    driver_build &&
    remove_context_shared_memory_bin &&
    driver_body
}

if [ $# -eq 0 ]
  then
    run
else
    echo ">>>>>>Invoking $1 <<<<<<<<"
    $1
fi
