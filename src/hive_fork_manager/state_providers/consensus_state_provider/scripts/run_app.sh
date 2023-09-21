#!/bin/bash

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
    sudo rm -rf /home/hived/datadir/haf_db_store/shmem/ || true

    psql  -v "ON_ERROR_STOP=1" -d haf_block_log -c "select hive.app_reset_data('cabc');"
    
    psql -v "ON_ERROR_STOP=1" -d haf_block_log -f $SRC_DIR/src/hive_fork_manager/state_providers/performance_examination/current_account_balance_app.sql 
    
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


if [ $# -eq 0 ]
  then
    run
else
    echo ">>>>>>Invoking $1 <<<<<<<<"
    $1
fi

