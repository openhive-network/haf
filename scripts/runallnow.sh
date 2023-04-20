#!/bin/bash


set -e


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


# we are in build directory

# mtlk TODO
# DONE start/stop on contextual shared mem file
# DONE What about ON CONFLICT DO NOTHING in src/hive_fork_manager/state_providers/current_account_balance.sql - two accounts in one state ?     texcik = format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances_C(%L) ON CONFLICT DO NOTHING;', __table_name, _context);
# consuming jsons one by one or getting a vector of blocks form haf block api
# DONE separate C function to get current block_num where we stand
# in yaml - cp log to . instead of ln -s
# separate from database_api.cpp, database_api_plugin

# //na krotkim blocklogu zobacz jak to push blok chodzi

# lock na funckjach w C lub wyżej

#  is it needed ?         bfs::permissions(abs_path, b
#  better "PGDATA" get_context_data_dir() // //getenv("HAF_DB_STORE");//BLOCK_LOG_DIRECTORY
# why runall script has to clear contest sharedmemory.bin ?
# funkcja do zwracania + 'blockchain' 
# test for many contexts
# expected_block_num no global var

# new a nie ma delete , moze smart pointer ?
# Opcja data dir do state provid conse

# app_cont full 5M - 155m41.347
# app_cont only get_block 5M - 119m47.842s
# app_cont Measure json w/o __jb 121m9.764s

# app_cont Idle run  5M -  1m49.750s

# app_cont full 5M - 1000 chunk - 54m55.956s
# app_cont full 5M - 10000 chunk - 36m1.211s
# app_cont full 5M - 20000 chunk - 33m19.227s

 # app_cont full 5M 13m21.138s -grab first measure (wlogs)
 # app_cont full 5M 8m22.943s -grab first measure (no wlogs)

 # app_cont full 5M 63m5.992 -grab+consume, but with checks
 # app_cont full 5M 43m7.279s - -grab+consume, but with checks, but with MULTISIGS_IN_C
 # app_cont full 5M 25m41.722s -- via variant (w/o json) MULTISIGS_IN_C
  
# app_cont full 5M - 100000, 50000 - # NOTICE:  CConsuming blocks from 3302001 to 3402000
# ERROR:  total size of jsonb array elements exceeds the maximum of 268435455 bytes
# CONTEXT:  SQL statement "SELECT jsonb_build_object(
#         'blocks', COALESCE(array_agg(


# Database api zmniejszyc

# Run serialize 5m app overnight 
# Blockloga wlacz zobacz czas


# Interesting blocks< 5M
# Select block_num, array_agg(trx_in_block), array_agg(op_pos) from hive.operations where trx_in_block > 5 and op_pos > 5 group by block_num;
# select * from hive.operations where block_num =3183805 order by trx_in_block, op_pos;
# https://hiveblockexplorer.com/block/3183805
# https://hivehub.dev/b/4802489


# suspected blocks - assert +    if (block_num >= 2726330)


# check all:
# how to run: /home/dev/haf_consensus_state_provider/debug_build/hive/programs/hived/hived --webserver-ws-endpoint=0.0.0.0:8091 --webserver-http-endpoint=0.0.0.0:8090 --p2p-endpoint=0.0.0.0:2001 --data-dir=$DATA_DIR --shared-file-dir=$DATA_DIR/blockchain --validate-during-replay --blockchain-thread-pool-size=1 --stop-replay-at-block=2000 --force-replay --replay --exit-before-sync 

# how to run: psql -a  -d haf_block_log -c '\timing'  -c "select hive.try_grab_operations(1, 10, 'ala')"


# TODO why is needed - otherwise not from 0 - sudo rm  /var/lib/postgresql/blockchain/cabc_shared_memory.bin  || true

# TODO - debug stop_in_failed_verify_authority transaction_util.cpp:80       verify_authority     ] runal jesus2 auth={"weight_threshold":1,"account_auths":[],"key_auths":[["STM8UsRn6HbmRXkQSTtLRsUmXzb1HEvad5xU6AVY2XTugxYdd8s6P",1]]} owner={"weight_threshold":1,"account_auths":[],"key_auths":[["STM82yPKqrrrUEhuVYNEHEEqRWU16b4uyRmW6MXPDEzZgpJey9rsB",1]]} block_num=3705110
#    so recompile with O0 , run and attach postgres

# TODO remove file try_grab_operations.hpp

# TODO 16 magic number in account                 CHAR(16),

# TODO check if binary data can be taken from hive::operation

# TODO use unlink to automatically delete a file when connection (process) goes down


# bool czy_printowac(int block_num)
# {
#   //   switch(block_num)
#   //   {  
#   //     case 1093:
#   //     case 994240:
#   //     case 1021529:
#   //     case 3143833:
#   //     case 3208405:
#   //     case 3695672:
#   //     case 3705111:
#   //     case 3705120:
#   //     case 3713940:
#   //     case 3714132:
#   //     case 3714567:
#   //     case 3714588:
#   //     case 4138790:
#   //     case 4338089:
#   //     case 4626205:
#   //     case 4632595:

#   //     //case 3705111:
#   //     //case 3705120:
#   //     //case 3713940:
#   //     //case 3714132:
#   //     //case 3714567:
#   //     //case 3714588:
#   //     //case 4138790:



#   //       return true;
#   // }

#   return false;
# }


    #   //legacy asset
    #   switch(block_num)
    #   {
    #   //   case  994240:        //"account_creation_fee": "0.1 HIVE"
    #   //   case 1021529:        //"account_creation_fee": "10.0 HIVE"
    #   //   case 3143833:        //"account_creation_fee": "3.00000 HIVE"
    #   //   case 3208405:        //"account_creation_fee": "2.00000 HIVE"
    #   //   case 3695672:        //"account_creation_fee": "3.00 HIVE"
    #   //   case 4338089:        //"account_creation_fee": "0.001 0.001"
    #   //   case 4626205:        //"account_creation_fee": "6.000 6.000"
    #   //   case 4632595:        //"account_creation_fee": "6.000 6.000"
    #   //     break;

    #   // //just wrong merkle
    #   //   case 3705111:
    #   //   case 3705120:
    #   //   case 3713940:
    #   //   case 3714132:
    #   //   case 3714567:
    #   //   case 3714588:
    #   //   case 4138790:
    #   //     break;
        
    #     default:



BUILD_DIR=.
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir
# DATA_DIR=/home/dev/mainnet-5m




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

local CMAKED=false
local EXIT_STATUS=0

if [[ "$PWD" =~ debug_build$ ]] 
then
    cmake  -DCMAKE_BUILD_TYPE=Debug -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-O0 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # Debug O0
    # cmake  -DCMAKE_BUILD_TYPE=Debug -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-O2 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # Debug O2

    CMAKED=true


elif [[ "$PWD" =~ build$ ]]
then

    cmake  -DCMAKE_BUILD_TYPE=Release -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-fdiagnostics-color=always" -GNinja $SRC_DIR ;  # Release
   
    CMAKED=true

else
    echo "NOT in build directory!!!"
fi

if [[ $CMAKED ]]
then
    ninja  hived extension.hive_fork_manager  \
        && sudo ninja install \
        && sudo chown $USER:$USER .ninja_*  \
        && ctest -R keyauth --output-on-failure \
        && ctest -R curr --output-on-failure
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
    
    psql -v "ON_ERROR_STOP=1" -d haf_block_log -f $SRC_DIR/src/hive_fork_manager/state_providers/performance_examination/current_account_balance_app.sql 
    
    psql -a -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing'  -c "call cab_app.main('cabc', $RUN_APP_MAIN_TILL_BLOCK, $RUN_APP_MAIN_CHUNK_SIZE)" -c 'select * from hive.cabc_c_a_b_s_t LIMIT 30;' -c 'select count(*) from hive.cabc_accounts;' 2>&1 | tee -i app.log # run
}

app_cont()
{
    permissions
    echo "Before app_cont"
    time psql -v "ON_ERROR_STOP=1" -d haf_block_log -c '\timing' \
    -c "call cab_app.main('cabc', $RUN_APP_CONT_MAIN_TILL_BLOCK, $RUN_APP_CONT_MAIN_CHUNK_SIZE)" \
    -c 'select * from hive.cabc_c_a_b_s_t limit 30;' -c 'select count(*) from hive.cabc_accounts;' \
    -c 'select SUM(balance) from hive.cabc_c_a_b_s_t' \
    2>&1 | tee -i app.log # run
    echo "After app_cont"
}



permissions()
{
    chmod 777 $DATA_DIR/blockchain/shared_memory.bin || true
    chmod 777 $DATA_DIR/blockchain || true
    sudo chmod 777 $DATA_DIR/blockchain/* || true

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
    run_all_from_scratch && app_start && time app_cont
}

if [ $# -eq 0 ]
  then
    run
else
    echo ">>>>>>Invoking $1 <<<<<<<<"
    $1
fi



