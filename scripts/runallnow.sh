#!/bin/bash

# ../haf/scripts/runallnow.sh 20000 driver
# rm /home/hived/datadir/consensus_state_provider/blockchain/shared_memory.bin ; ./bin/consp_driver --to 1091


# remove transactions
# remove  -  process_header_extensions -> CANNOT because header extensions patch witness verson after fork .of 1934237,  -> if( has_hardfork( HIVE_HARDFORK_0_5__54 ) ) // Cannot remove after hardfork 
#    and -> 2791017 FC_ASSERTS in hive evaluator

# modern :  8  "Postgres",  221  "Trans", and approximately 544 seconds were spent on "All".  Alltogether:10'35" 10'01" no_transactions = 6'30"
# classic :Postgres 73 Transf: 227 "ALL:704 , 9'53"



# block 23645967 //FC_ASSERT( vo.amount >= 0, "Asset amount cannot be negative" );   - nijeah 

# compile RelWithDebInfo : 8 min 18sec
# compile Release : 6 min 32sec



: <<'END_COMMENT'
 18,993,603
2,325,194ms database.cpp:211              operator()           ] Attempting to rewind all undo state...
2,325,194ms database.cpp:215              operator()           ] Rewind undo state done.
2,325,194ms database.cpp:225              operator()           ] Blockchain state database is AT IRREVERSIBLE state specific to head block: 18,993,619 and LIB: 18,993,603
2,325,194ms consensus_state_provider_replay.cpp:330 consensus_state_prov ] ERROR: Cannot replay consensus state provider: Initial "from" block number is 1, but current state is expecting 18,993,620
 took: 0 hours, 0 minutes, 0 seconds
END_COMMENT


: <<'END_LAUNCH_DBG_CONFIGURATION'
       {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/../build/bin/consp_driver",
            "args": ["--allow-reevaluate", "--from=23645966"],
            "stopAtEntry": true,
            "cwd": "${fileDirname}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "Set Disassembly Flavor to Intel",
                    "text": "-gdb-set disassembly-flavor intel",
                    "ignoreFailures": true
                }
            ]
        }
END_LAUNCH_DBG_CONFIGURATION

# root" execution of the PostgreSQL server is not permitted.
# The server must be started under an unprivileged user ID to prevent
# possible system security compromise.  See the documentation for


# valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=./callgrind.out.%p /usr/lib/postgresql/14/bin/postgres --config_file=/etc/postgresql/14/main/postgresql.conf

# proby byly 
# 1. -static-libasan:
# SET(HIVE_ASAN_LINK_OPTIONS  -fsanitize=address)  -> SET(HIVE_ASAN_LINK_OPTIONS -static-libasan -fsanitize=address)

# 2. driver of postgres functions 
# src/hive_fork_manager/shared_lib/CMakeLists.txt:
# ADD_EXECUTABLE(consp_driver
    
#   mtlk_main.cpp
# )

# ADD_POSTGRES_INCLUDES( consp_driver )
# ADD_POSTGRES_LIBRARIES( consp_driver )

# target_link_libraries(consp_driver
#     PRIVATE ${target_name}
# )

#    src/hive_fork_manager/shared_lib/mtlk_main.cpp:

# #include "operation_base.hpp"

# #include <hive/protocol/forward_impacted.hpp>
# #include <hive/protocol/misc_utilities.hpp>

# #include <fc/io/json.hpp>
# #include <fc/string.hpp>

# #include <vector>



# #include "postgres.h"
# #include "fmgr.h"

# PG_FUNCTION_INFO_V1(consensus_state_provider_replay);

# Datum consensus_state_provider_replay(PG_FUNCTION_ARGS);



# int main()
# {
#     consensus_state_provider_replay();
#     return 0;
# }



: <<'END_COMMENT'
w stogage big logi:  bylo IF FALSE THEN -- mtlk try_grab_operations
OTICE:  __consensus_state_provider_replay_call_ok=t
NOTICE:  Block range: <11836249, 13315529> processed successfully.
NOTICE:  Processing block range: <13315530, 14794810>
NOTICE:  consensus_state_provider_replay
NOTICE:  __postgres_url=postgres:///haf_block_log
NOTICE:  __shared_memory_bin_path=/home/hived/datadir/consensus_state_provider/cabc
server closed the connection unexpectedly
        This probably means the server terminated abnormally
        before or while processing the request.
connection to server was lost

real    344m20.536s
user    0m0.032s
sys     0m0.012s

real    344m20.536s
user    0m0.032s

0       SQL statement "SELECT hive.app_state_providers_update(_from, _to, _app_context)"
        PL/pgSQL function cab_app.process_block_range_data_c(character varying,integer,integer,integer) line 3 at PERFORM
        SQL statement "SELECT cab_app.process_block_range_data_c(_appContext, b, _last_block)"
        PL/pgSQL function cab_app.process_block_range_loop(character varying,integer,integer,integer,integer) line 11 at PERFORM
        SQL statement "CALL cab_app.process_block_range_loop(_appContext, _from, _to, _step, _last_block)"
        PL/pgSQL function cab_app.do_massive_processing(character varying,integer,integer,integer,integer) line 9 at CALL
        SQL statement "CALL cab_app.do_massive_processing(_appContext, __from, __to, _step, __last_block)"
        PL/pgSQL function cab_app.main(character varying,integer,integer,text) line 27 at CALL
2023-05-12 09:55:44.685 CEST [105827] haf_admin@haf_block_log NOTICE:  __shared_memory_bin_path=/home/hived/datadir/consensus_state_provider/cabc
2023-05-12 09:55:44.685 CEST [105827] haf_admin@haf_block_log CONTEXT:  PL/pgSQL function hive.update_state_provider_c_a_b_s_t(integer,integer,hive.context_name) line 31 at RAISE
        SQL statement "SELECT hive.update_state_provider_c_a_b_s_t( 13315530, 14794810, 'cabc' )"
        PL/pgSQL function hive.update_one_state_providers(integer,integer,hive.state_providers,hive.context_name) line 3 at EXECUTE
        SQL statement "SELECT hive.update_one_state_providers( _first_block, _last_block, hsp.state_provider, _context )
            FROM hive.state_providers_registered hsp
            WHERE hsp.context_id = __context_id"
        PL/pgSQL function hive.app_state_providers_update(integer,integer,hive.context_name) line 28 at PERFORM
        SQL statement "SELECT hive.app_state_providers_update(_from, _to, _app_context)"
        PL/pgSQL function cab_app.process_block_range_data_c(character varying,integer,integer,integer) line 3 at PERFORM
        SQL statement "SELECT cab_app.process_block_range_data_c(_appContext, b, _last_block)"
        PL/pgSQL function cab_app.process_block_range_loop(character varying,integer,integer,integer,integer) line 11 at PERFORM
        SQL statement "CALL cab_app.process_block_range_loop(_appContext, _from, _to, _step, _last_block)"
        PL/pgSQL function cab_app.do_massive_processing(character varying,integer,integer,integer,integer) line 9 at CALL
        SQL statement "CALL cab_app.do_massive_processing(_appContext, __from, __to, _step, __last_block)"
        PL/pgSQL function cab_app.main(character varying,integer,integer,text) line 27 at CALL
2023-05-12 14:22:14.314 CEST [94480] LOG:  server process (PID 105827) was terminated by signal 9: Killed
2023-05-12 14:22:14.314 CEST [94480] DETAIL:  Failed process was running: call cab_app.main('cabc', 73964098, 1479281, '/home/hived/datadir/consensus_state_provider')
2023-05-12 14:22:14.315 CEST [94480] LOG:  terminating any other active server processes
2023-05-12 14:22:14.360 CEST [94480] LOG:  all server processes terminated; reinitializing
2023-05-12 14:22:15.671 CEST [107554] LOG:  database system was interrupted; last known up at 2023-05-12 10:48:19 CEST
2023-05-12 14:22:16.346 CEST [107554] LOG:  database system was not properly shut down; automatic recovery in progress
2023-05-12 14:22:16.354 CEST [107554] LOG:  invalid record length at 1196/74C97140: wanted 24, got 0
2023-05-12 14:22:16.354 CEST [107554] LOG:  redo is not required
2023-05-12 14:22:16.425 CEST [94480] LOG:  database system is ready to accept connections
dev@zk-29:/storage1

Possibly OOM:

NOTICE:  Block range: <11836249, 13315529> processed successfully.
NOTICE:  Processing block range: <13315530, 14794810>
NOTICE:  consensus_state_provider_replay
NOTICE:  __postgres_url=postgres:///haf_block_log
NOTICE:  __shared_memory_bin_path=/home/hived/datadir/consensus_state_provider/cabc
server closed the connection unexpectedly
	This probably means the server terminated abnormally
	before or while processing the request.
connection to server was lost

2023-05-12 09:55:44.685 CEST [105827] haf_admin@haf_block_log NOTICE:  __shared_memory_bin_path=/home/hived/datadir/consensus_state_provider/cabc
2023-05-12 09:55:44.685 CEST [105827] haf_admin@haf_block_log CONTEXT:  PL/pgSQL function hive.update_state_provider_c_a_b_s_t(integer,integer,hive.context_name) line 31 at RAISE
	SQL statement "SELECT hive.update_state_provider_c_a_b_s_t( 13315530, 14794810, 'cabc' )"
	PL/pgSQL function hive.update_one_state_providers(integer,integer,hive.state_providers,hive.context_name) line 3 at EXECUTE
	SQL statement "SELECT hive.update_one_state_providers( _first_block, _last_block, hsp.state_provider, _context )
	    FROM hive.state_providers_registered hsp
	    WHERE hsp.context_id = __context_id"
	PL/pgSQL function hive.app_state_providers_update(integer,integer,hive.context_name) line 28 at PERFORM
	SQL statement "SELECT hive.app_state_providers_update(_from, _to, _app_context)"
	PL/pgSQL function cab_app.process_block_range_data_c(character varying,integer,integer,integer) line 3 at PERFORM
	SQL statement "SELECT cab_app.process_block_range_data_c(_appContext, b, _last_block)"
	PL/pgSQL function cab_app.process_block_range_loop(character varying,integer,integer,integer,integer) line 11 at PERFORM
	SQL statement "CALL cab_app.process_block_range_loop(_appContext, _from, _to, _step, _last_block)"
	PL/pgSQL function cab_app.do_massive_processing(character varying,integer,integer,integer,integer) line 9 at CALL
	SQL statement "CALL cab_app.do_massive_processing(_appContext, __from, __to, _step, __last_block)"
	PL/pgSQL function cab_app.main(character varying,integer,integer,text) line 27 at CALL
2023-05-12 14:22:14.314 CEST [94480] LOG:  server process (PID 105827) was terminated by signal 9: Killed
2023-05-12 14:22:14.314 CEST [94480] DETAIL:  Failed process was running: call cab_app.main('cabc', 73964098, 1479281, '/home/hived/datadir/consensus_state_provider')
2023-05-12 14:22:14.315 CEST [94480] LOG:  terminating any other active server processes
2023-05-12 14:22:14.360 CEST [94480] LOG:  all server processes terminated; reinitializing
2023-05-12 14:22:15.671 CEST [107554] LOG:  database system was interrupted; last known up at 2023-05-12 10:48:19 CEST

END_COMMENT


: <<'END_LOG_STEEMIT_10'

NOTICE:  __consensus_state_provider_replay_call_ok=t
NOTICE:  Accounts 15 richest=
[{"account":"bittrex","balance":26631803568,"hbd_balance":7440023071,"vesting_shares":8538578636896,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"poloniex","balance":14479859394,"hbd_balance":471584280,"vesting_shares":4404577000000,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"binance-hot","balance":2841822449,"hbd_balance":606,"vesting_shares":1023055299,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"steemit2","balance":2517006058,"hbd_balance":4992066,"vesting_shares":270658494645704,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"ben","balance":1982777755,"hbd_balance":921,"vesting_shares":471404505904935,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"imadev","balance":788297714,"hbd_balance":446,"vesting_shares":445256469401562,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"alpha","balance":460889906,"hbd_balance":1626030,"vesting_shares":82084887877,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"muchfun","balance":415000003,"hbd_balance":102,"vesting_shares":12360924266,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"upbit-exchange","balance":397609092,"hbd_balance":456297979,"vesting_shares":10236655591659,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"gopax-deposit","balance":376411256,"hbd_balance":54070439,"vesting_shares":5157727615249,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"freewallet","balance":326483367,"hbd_balance":1133,"vesting_shares":46804933931,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"val-a","balance":319164942,"hbd_balance":539,"vesting_shares":2184996452620127,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"dan","balance":311501016,"hbd_balance":426221,"vesting_shares":384455200934425,"savings_hbd_balance":0,"reward_hbd_balance":164860}, 
 {"account":"dantheman","balance":300198007,"hbd_balance":98453,"vesting_shares":212148717653,"savings_hbd_balance":0,"reward_hbd_balance":344}, 
 {"account":"openledger-dex","balance":298120536,"hbd_balance":28033741,"vesting_shares":1033789880,"savings_hbd_balance":0,"reward_hbd_balance":0}]
NOTICE:  Block range: <19232654, 20711934> processed successfully.
NOTICE:  Processing block range: <20711935, 22191215>
NOTICE:  consensus_state_provider_replay
NOTICE:  __postgres_url=postgres:///haf_block_log
NOTICE:  __shared_memory_bin_path=/home/hived/datadir/consensus_state_provider/cabc
NOTICE:  __consensus_state_provider_replay_call_ok=t
NOTICE:  Accounts 15 richest=
[{"account":"bittrex","balance":23234293467,"hbd_balance":8652108199,"vesting_shares":8538578636896,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"poloniex","balance":14479922603,"hbd_balance":471584529,"vesting_shares":4404577000000,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"binance-hot","balance":5652567614,"hbd_balance":3594,"vesting_shares":1023055299,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"ben","balance":2213971486,"hbd_balance":926,"vesting_shares":659751021,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"huobi-withdrawal","balance":2193088215,"hbd_balance":1,"vesting_shares":4079848926560,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"steemit","balance":1600000006,"hbd_balance":8582279,"vesting_shares":90039851836689703,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"steemit2","balance":1185903095,"hbd_balance":4992069,"vesting_shares":232177656843878,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"upbit-exchange","balance":818830175,"hbd_balance":773295567,"vesting_shares":10236655591659,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"imadev","balance":788297714,"hbd_balance":451,"vesting_shares":445256469401562,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"dan","balance":471203857,"hbd_balance":426820,"vesting_shares":58822357508745,"savings_hbd_balance":0,"reward_hbd_balance":166068}, 
 {"account":"muchfun","balance":415000004,"hbd_balance":102,"vesting_shares":12360924266,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"proskynneo","balance":308538850,"hbd_balance":300,"vesting_shares":1806836645106858,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"dantheman","balance":300198007,"hbd_balance":98520,"vesting_shares":212148717653,"savings_hbd_balance":0,"reward_hbd_balance":344}, 
 {"account":"amcq","balance":290000001,"hbd_balance":263987,"vesting_shares":8808070581,"savings_hbd_balance":0,"reward_hbd_balance":0}, 
 {"account":"openledger-dex","balance":286457049,"hbd_balance":35188360,"vesting_shares":1033789880,"savings_hbd_balance":0,"reward_hbd_balance":0}]
NOTICE:  Block range: <20711935, 22191215> processed successfully.
NOTICE:  Processing block range: <22191216, 23670496>
NOTICE:  consensus_state_provider_replay
NOTICE:  __postgres_url=postgres:///haf_block_log
NOTICE:  __shared_memory_bin_path=/home/hived/datadir/consensus_state_provider/cabc
server closed the connection unexpectedly
        This probably means the server terminated abnormally
        before or while processing the request.

END_LOG_STEEMIT_10

# sudo rm /home/hived/datadir/context/blockchain/shared_memory.bin; ../haf/scripts/runallnow.sh build
# rsync -avh   /home/haf_admin/haf /home/hived/datadir/src/


# valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=./callgrind.out.%p /usr/lib/postgresql/14/bin/postgres --config_file=/etc/postgresql/14/main/postgresql.conf

# proby byly 
# 1. -static-libasan:
# SET(HIVE_ASAN_LINK_OPTIONS  -fsanitize=address)  -> SET(HIVE_ASAN_LINK_OPTIONS -static-libasan -fsanitize=address)

# 2. driver of postgres functions 
# src/hive_fork_manager/shared_lib/CMakeLists.txt:
# ADD_EXECUTABLE(consp_driver
    
#   mtlk_main.cpp
# )

# ADD_POSTGRES_INCLUDES( consp_driver )
# ADD_POSTGRES_LIBRARIES( consp_driver )

# target_link_libraries(consp_driver
#     PRIVATE ${target_name}
# )

#    src/hive_fork_manager/shared_lib/mtlk_main.cpp:

# #include "operation_base.hpp"

# #include <hive/protocol/forward_impacted.hpp>
# #include <hive/protocol/misc_utilities.hpp>

# #include <fc/io/json.hpp>
# #include <fc/string.hpp>

# #include <vector>



# #include "postgres.h"
# #include "fmgr.h"

# PG_FUNCTION_INFO_V1(consensus_state_provider_replay);

# Datum consensus_state_provider_replay(PG_FUNCTION_ARGS);



# int main()
# {
#     consensus_state_provider_replay();
#     return 0;
# }



# sudo rm /home/hived/datadir/context/blockchain/shared_memory.bin; ../haf/scripts/runallnow.sh build
# rsync -avh   /home/haf_admin/haf /home/hived/datadir/src/


# stopping app: select cab_app.stop_processing();

# valgrind 
#     --fullpath-after=10   
#     --show-leak-kinds=all  
#     --soname-synonyms=somalloc=none 
#     --track-origins=yes 
#     --trace-children=yes  
#     --leak-check=full 
#     --log-file=valgrind.log  
#     /usr/lib/postgresql/14/bin/postgres --config_file=/etc/postgresql/14/main/postgresql.conf


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




# mtlk TODO:



# Odpal
#     bool database::_push_block(const block_flow_control& block_ctrl)
# zamiast apply_block

# TODO - erase nodes from fork db after pop_block
# TODO - eliminate removing undo_all at the beginning
# TODO taking data from hive.block_view , perhaps from hive.operations, hive.transactions - views ?



# Dgpo
# Wszystko  z konta
# connection

# Zablokuj wspoldostęp do sharedmemory file?


# Csp_session. Ma pyr do bazy danych 
# Zamiast globala


# Transakcje. Granica transakcji


# 2.Push_block zamiast apply block
# Swoja block control - moze więcej virtualek

# DONE # 1.fynna block log ujednolixix kod - hived blockloga head block z góry.

# 0. Varianty wywalić

# DONE Wydajnosc block po bloku. Na obecnej wersji


# TODO!!!  -- ile zajmuje init - moze mozna go za każdym razem robić i w ten sposób reentrant!!!

# TODO list all blocks and acounts with negative asset (ranges of blocks, maybe)
#            //FC_ASSERT( vo.amount >= 0, "Asset amount cannot be negative" );
#         if(vo.amount < 0)
#           if(mtlk_negative_asset_counter++ % 10000 == 0)
#             wlog("Asset amount cannot be negative = ${neg_ass}" , ("neg_ass", vo.amount));


# TODO rename IBlockProvider to Iblock_log
# TODO test na start_fork - DIP 
# TODO in bash_test - nake runallnow.sh or do another file, so that it contains just script
# TODO - rename - everything should be named csp - consensus state prvider, sometimes only - cab - current_account_balances
# TODO make it truly  switchable with classic version - command line param = switching from  trans to non trans, -> eliminate ?
# TODO cond copy and copy operations buffer - use cast or move modern version not pqxx
# TODO
# TODO
# TODO wywal w ogóle state providera z cab_app i uzywaj tylko funkcji z src/hive_fork_manager/consensus_state_provider_helpers.sql
# TODO cleanup init(db
# TODO remove mtlk
# TODO are all headers included ?
# TODO #include" vs. #include<
# TODO remove wlog, and put info where applicable
# TODO example testing app - move to proper place in directory tree
# TODO interface ?, name consensu or context or current_acount_balance provider ?
# TODO flag constructors / destructors default
# TODO constants in collect_current_all_accounts_balances , 
# TODO clean garbage in /home/hived/datadir/consensus_storage when it cannot start (rg. when going Debug from Release
# TODO split into commits. for example, "an additional parameter in state providers due to the necessity of passing there the disk path to the storage of the consensus state provider".
# TODO ask data_processor::handle_exception( std::exception_ptr exception_ptr ) {
# TODO magic numbers: args.limit = 1000;
# TODO - ASK + " AND op_type_id <= 49 " //TODO how to determine where vops start ? -> //trx_in_block < 0 -> virtual operation
# TODO wywal inne state providery z appki np ACCOUNTS
# TODO* example testing app - move to proper place in directory tree
# TODO* ? in yaml - cp log to . instead of ln -s
# TODO* why runallnow script has to clear contest sharedmemory.bin ? 
#    1. different N5boost10wrapexceptISt13runtime_errorEE: Different persistent & runtime environments. Persistent

# TODO name consensus provider and current account provider properly
# TODO separate from database_api.cpp, database_api_plugin
# TODO uncomment this test : (check in CI)//BOOST_CHECK_THROW( fc::json::from_string( "{\"amount\":\"-1\",\"precision\":3,\"nai\":\"@@000000021\"}" ).as< asset >(), fc::exception );

# TODO ? lock na funckjach w C lub wyżej
# TODO funkcja do zwracania + 'blockchain' 
# TODO test for many contexts
# TODO new db a nie ma delete , moze smart pointer ?

# TODO //na krotkim blocklogu zobacz jak to push blok chodzi


# TODO 16 magic number in account                 CHAR(16),

# TODO hierarchical handling of exceptions
# TODO - LATER try to reconnect ? try_to_restore_connection();
# TODO - LATER  clangcheck if binary data can be taken from hive::operation
# TODO - LATER  clanguse unlink to automatically delete a file when connection (process) goes down
# TODO - LATER  clang find #include
# TODO - LATER ?  add .clang-format 


# DONE Remove allow_reevaluate
# DONE measurements of phases for trans and non_trans
# DONE add interface to get a particular account balance
# DONE ASAN - memory leaks
# DONE from_variant_to_full_block_ptr.cpp file not needed
# DONE separate driver for C code
# DONE rename moider to no_transaction - non_transactional_version simple_version direct_operation_version
# DONE struct postgres_block_log into class
# DONE maybe revert a bit of code in code and pass a lambda ??
# DONE pfree in utitlities.cpp where needed
# DONE rename test_givena
# DONE rename transactions_it to current_transaction
# DONE? refactor app.main
# DONE #include <../../../apis/block_api/include/hive/plugins/block_api/block_api_objects.hpp>
# DONE - recognize existing context_shared_memory_bin
# DONE eliminate _FROM_VARIANT_ON_CONSUME_JSON_HACK
# DONE - bash_test assert
# DONE - remove permissions from app_cont


# DONE exceptions handling in pqxx usage
# DONE start/stop on contextual shared mem file
# DONE What about ON CONFLICT DO NOTHING in src/hive_fork_manager/state_providers/current_account_balance.sql - two accounts in one state ?     texcik = format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances(%L) ON CONFLICT DO NOTHING;', __table_name, _context);
# DONE (minor gain )consuming jsons one by one or getting a vector of blocks form haf block api
# DONE separate C function to get current block_num where we stand

# DONE (eliminated) is it needed ?         bfs::permissions(abs_path, b
# DONE (eliminated in favor of explicit parameter) better "PGDATA" get_context_data_dir() // //getenv("HAF_DB_STORE");//BLOCK_LOG_DIRECTORY
# DONE expected_block_num no global var

# DONE Opcja data dir do state provid conse

# mostly DONE Database api zmniejszyc

# DONE Run serialize 5m app overnight 
# Run serialize 73m app overnight 
# Blockloga wlacz zobacz czas



# end mtlk TODO


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





: <<'NO_TRANS'
Stepping from 68,400,001 to 68,500,000 Blocks:100,000 Transactions:7,864,692 Operations:7,950,520 Postgres:0'56" Trans:0'1" All:1'58" Memory (KB): 25,065,240                              │.cache/               h
Alltogether:994'0"                                                                                                                                                                         │ive_base_config/     .w
real    994m1.184s                                                                                                                                                                         │get-hsts
user    603m4.340s                                                                                                                                                                         │docker_entrypoint.sh  .
sys     75m56.102s                                                                                                                                                                         │lesshst              
haf_admin@7136cb35cacd:~/build$   

epping from 73,400,001 to 73,500,000 Blocks:100,000 Transactions:6,098,335 Operations:6,202,895 Postgres:0'53" Trans:0'2" All:1'57" Memory (KB): 30,761,840                              │gnupg/               .s
Stepping from 73,500,001 to 73,600,000 Blocks:100,000 Transactions:6,098,263 Operations:6,224,850 Postgres:0'53" Trans:0'2" All:1'59" Memory (KB): 30,836,416                              │sh/
Stepping from 73,600,001 to 73,700,000 Blocks:100,000 Transactions:6,082,636 Operations:6,188,354 Postgres:0'53" Trans:0'2" All:1'55" Memory (KB): 30,845,080                              │build/                h
Stepping from 73,700,001 to 73,800,000 Blocks:100,000 Transactions:5,689,922 Operations:5,797,091 Postgres:0'50" Trans:0'1" All:1'51" Memory (KB): 30,863,540                              │af/                  .v
Stepping from 73,800,001 to 73,900,000 Blocks:100,000 Transactions:6,003,454 Operations:6,104,819 Postgres:0'51" Trans:0'2" All:1'54" Memory (KB): 30,775,008                              │scode-server/
Stepping from 73,900,001 to 73,964,098 Blocks:64,098 Transactions:3,912,128 Operations:3,995,864 Postgres:0'33" Trans:0'1" All:1'14" Memory (KB): 30,847,584                               │.cache/               h
Alltogether:117'10"                                                                                                                                                                        │ive_base_config/     .w
real    117m11.664s                                                                                                                                                                        │get-hsts
user    57m45.463s                                                                                                                                                                         │docker_entrypoint.sh  .
sys     6m28.349s                                                                                                                                                                          │lesshst              
haf_admin@7136cb35cacd:~/build$                                                                                                                                                            │haf_admin@7136cb35cacd:
────────────────────────────────────
NO_TRANS


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

# DONE - debug stop_in_failed_verify_authority transaction_util.cpp:80       verify_authority     ] runal jesus2 auth={"weight_threshold":1,"account_auths":[],"key_auths":[["STM8UsRn6HbmRXkQSTtLRsUmXzb1HEvad5xU6AVY2XTugxYdd8s6P",1]]} owner={"weight_threshold":1,"account_auths":[],"key_auths":[["STM82yPKqrrrUEhuVYNEHEEqRWU16b4uyRmW6MXPDEzZgpJey9rsB",1]]} block_num=3705110
#    so recompile with O0 , run and attach postgres

# DONE remove file try_grab_operations.hpp



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




#         EXPLAIN  WITH
#         -- hive.get_block_from_views
#         base_blocks_data AS MATERIALIZED (
#             SELECT
#                 hb.num,
#                 hb.prev,
#                 hb.created_at,
#                 hb.transaction_merkle_root,
#                 hb.witness_signature,
#                 COALESCE(hb.extensions,  array_to_json(ARRAY[] :: INT[]) :: JSONB) AS extensions,
#                 hb.producer_account_id,
#                 hb.hash,
#                 hb.signing_key,
#                 ha.name
#             FROM hive.blocks_view hb
#             JOIN hive.accounts_view ha ON hb.producer_account_id = ha.id
#             WHERE hb.num BETWEEN 1100 AND ( 1100 +   1   - 1 )
#             ORDER BY hb.num ASC
#         ),
#         trx_details AS MATERIALIZED (
#             SELECT
#                 htv.block_num,
#                 htv.trx_in_block,
#                 htv.expiration,
#                 htv.ref_block_num,
#                 htv.ref_block_prefix,
#                 htv.trx_hash,
#                 htv.signature
#             FROM hive.transactions_view htv
#             WHERE htv.block_num BETWEEN 1100 AND ( 1100 +   1   - 1 )
#             ORDER BY htv.block_num ASC, htv.trx_in_block ASC
#         ),
#         operations AS (
#                 SELECT ho.block_num, ho.trx_in_block, ARRAY_AGG(ho.body ORDER BY op_pos ASC) bodies
#                 FROM hive.operations_view ho
#                 WHERE
#                     ho.op_type_id <= (SELECT ot.id FROM hive.operation_types ot WHERE ot.is_virtual = FALSE ORDER BY ot.id DESC LIMIT 1)
#                     AND ho.block_num BETWEEN 1100 AND ( 1100 +   1   - 1 )
#                 GROUP BY ho.block_num, ho.trx_in_block
#                 ORDER BY ho.block_num ASC, trx_in_block ASC
#         ),
#         full_transactions_with_signatures AS MATERIALIZED (
#                 SELECT
#                     htv.block_num,
#                     ARRAY_AGG(htv.trx_hash ORDER BY htv.trx_in_block ASC) AS trx_hashes,
#                     ARRAY_AGG(
#                         (
#                             htv.ref_block_num,
#                             htv.ref_block_prefix,
#                             htv.expiration,
#                             ops.bodies,
#                             array_to_json(ARRAY[] :: INT[]) :: JSONB,
#                             (
#                                 CASE
#                                     WHEN multisigs.signatures = ARRAY[NULL]::BYTEA[] THEN ARRAY[ htv.signature ]::BYTEA[]
#                                     ELSE htv.signature || multisigs.signatures
#                                 END
#                             )
#                         ) :: hive.transaction_type
#                         ORDER BY htv.trx_in_block ASC
#                     ) AS transactions
#                 FROM
#                 (
#                     SELECT txd.trx_hash, ARRAY_AGG(htmv.signature) AS signatures
#                     FROM trx_details txd
#                     LEFT JOIN hive.transactions_multisig_view htmv
#                     ON txd.trx_hash = htmv.trx_hash
#                     GROUP BY txd.trx_hash
#                 ) AS multisigs
#                 JOIN trx_details htv ON htv.trx_hash = multisigs.trx_hash
#                 JOIN operations ops ON ops.block_num = htv.block_num AND htv.trx_in_block = ops.trx_in_block
#                 WHERE ops.block_num BETWEEN 1100 AND ( 1100 +   1   - 1 )
#                 GROUP BY htv.block_num
#                 ORDER BY htv.block_num ASC
#         )
#         SELECT 
#             bbd.num,
#             (
#                 bbd.prev,
#                 bbd.created_at,
#                 bbd.name,
#                 bbd.transaction_merkle_root,
#                 bbd.extensions,
#                 bbd.witness_signature,
#                 ftws.transactions,
#                 bbd.hash,
#                 bbd.signing_key,
#                 ftws.trx_hashes
#             ) :: hive.block_type
#         FROM base_blocks_data bbd
#         LEFT JOIN full_transactions_with_signatures ftws ON ftws.block_num = bbd.num
#         ORDER BY bbd.num ASC
#         ;

# "Merge Left Join  (cost=391.09..391.15 rows=9 width=36)"
# "  Merge Cond: (bbd.num = ftws.block_num)"
# "  CTE base_blocks_data"
# "    ->  Sort  (cost=159.70..159.73 rows=9 width=258)"
# "          Sort Key: hb.num"
# "          ->  Hash Join  (cost=62.24..159.56 rows=9 width=258)"
# "                Hash Cond: (ha.id = hb.producer_account_id)"
# "                ->  Append  (cost=0.00..93.64 rows=941 width=54)"
# "                      ->  Seq Scan on accounts ha  (cost=0.00..19.40 rows=940 width=54)"
# "                      ->  Subquery Scan on ""*SELECT* 2_1""  (cost=46.41..69.53 rows=1 width=54)"
# "                            ->  Hash Join  (cost=46.41..69.52 rows=1 width=58)"
# "                                  Hash Cond: ((har.fork_id = forks.max_fork_id) AND (har.block_num = forks.num))"
# "                                  ->  Seq Scan on accounts_reversible har  (cost=0.00..18.60 rows=860 width=66)"
# "                                  ->  Hash  (cost=45.55..45.55 rows=57 width=12)"
# "                                        ->  Subquery Scan on forks  (cost=44.41..45.55 rows=57 width=12)"
# "                                              ->  HashAggregate  (cost=44.41..44.98 rows=57 width=12)"
# "                                                    Group Key: hbr.num"
# "                                                    InitPlan 2 (returns $1)"
# "                                                      ->  Seq Scan on irreversible_data hid_1  (cost=0.00..32.00 rows=2200 width=4)"
# "                                                    ->  Seq Scan on blocks_reversible hbr  (cost=0.00..12.12 rows=57 width=12)"
# "                                                          Filter: (num > $1)"
# "                ->  Hash  (cost=62.21..62.21 rows=2 width=208)"
# "                      ->  Append  (cost=0.14..62.21 rows=2 width=208)"
# "                            ->  Index Scan using pk_hive_blocks on blocks hb  (cost=0.14..8.16 rows=1 width=208)"
# "                                  Index Cond: ((num >= 1100) AND (num <= 1100))"
# "                            ->  Subquery Scan on ""*SELECT* 2""  (cost=52.59..54.04 rows=1 width=208)"
# "                                  ->  Hash Join  (cost=52.59..54.03 rows=1 width=208)"
# "                                        Hash Cond: ((rb.num = hbr_1.num) AND ((max(rb.fork_id)) = hbr_1.fork_id))"
# "                                        ->  HashAggregate  (cost=44.41..44.98 rows=57 width=12)"
# "                                              Group Key: rb.num"
# "                                              InitPlan 1 (returns $0)"
# "                                                ->  Seq Scan on irreversible_data hid  (cost=0.00..32.00 rows=2200 width=4)"
# "                                              ->  Seq Scan on blocks_reversible rb  (cost=0.00..12.12 rows=57 width=12)"
# "                                                    Filter: (num > $0)"
# "                                        ->  Hash  (cost=8.16..8.16 rows=1 width=216)"
# "                                              ->  Index Scan using pk_hive_blocks_reversible on blocks_reversible hbr_1  (cost=0.14..8.16 rows=1 width=216)"
# "                                                    Index Cond: ((num >= 1100) AND (num <= 1100))"
# "  CTE trx_details"
# "    ->  Sort  (cost=69.08..69.09 rows=4 width=90)"
# "          Sort Key: ht.block_num, ht.trx_in_block"
# "          ->  Append  (cost=4.18..69.04 rows=4 width=90)"
# "                ->  Bitmap Heap Scan on transactions ht  (cost=4.18..11.30 rows=3 width=90)"
# "                      Recheck Cond: ((block_num >= 1100) AND (block_num <= 1100))"
# "                      ->  Bitmap Index Scan on hive_transactions_block_num_trx_in_block_idx  (cost=0.00..4.18 rows=3 width=0)"
# "                            Index Cond: ((block_num >= 1100) AND (block_num <= 1100))"
# "                ->  Subquery Scan on ""*SELECT* 2_2""  (cost=50.59..57.73 rows=1 width=90)"
# "                      ->  Hash Join  (cost=50.59..57.72 rows=1 width=90)"
# "                            Hash Cond: ((htr.fork_id = forks_1.max_fork_id) AND (htr.block_num = forks_1.num))"
# "                            ->  Bitmap Heap Scan on transactions_reversible htr  (cost=4.18..11.30 rows=3 width=98)"
# "                                  Recheck Cond: ((block_num >= 1100) AND (block_num <= 1100))"
# "                                  ->  Bitmap Index Scan on hive_transactions_reversible_block_num_trx_in_block_fork_id_idx  (cost=0.00..4.18 rows=3 width=0)"
# "                                        Index Cond: ((block_num >= 1100) AND (block_num <= 1100))"
# "                            ->  Hash  (cost=45.55..45.55 rows=57 width=12)"
# "                                  ->  Subquery Scan on forks_1  (cost=44.41..45.55 rows=57 width=12)"
# "                                        ->  HashAggregate  (cost=44.41..44.98 rows=57 width=12)"
# "                                              Group Key: hbr_2.num"
# "                                              InitPlan 4 (returns $3)"
# "                                                ->  Seq Scan on irreversible_data hid_2  (cost=0.00..32.00 rows=2200 width=4)"
# "                                              ->  Seq Scan on blocks_reversible hbr_2  (cost=0.00..12.12 rows=57 width=12)"
# "                                                    Filter: (num > $3)"
# "  CTE full_transactions_with_signatures"
# "    ->  GroupAggregate  (cost=161.45..161.92 rows=1 width=68)"
# "          Group Key: htv.block_num"
# "          ->  Nested Loop  (cost=161.45..161.88 rows=1 width=154)"
# "                Join Filter: (htv.trx_hash = txd.trx_hash)"
# "                ->  Merge Join  (cost=67.80..67.96 rows=1 width=122)"
# "                      Merge Cond: ((htv.block_num = ho.block_num) AND (htv.trx_in_block = ho.trx_in_block))"
# "                      ->  Sort  (cost=0.12..0.13 rows=4 width=90)"
# "                            Sort Key: htv.block_num, htv.trx_in_block"
# "                            ->  CTE Scan on trx_details htv  (cost=0.00..0.08 rows=4 width=90)"
# "                      ->  GroupAggregate  (cost=67.68..67.75 rows=3 width=38)"
# "                            Group Key: ho.block_num, ho.trx_in_block"
# "                            InitPlan 7 (returns $6)"
# "                              ->  Limit  (cost=0.15..0.25 rows=1 width=2)"
# "                                    ->  Index Scan Backward using pk_hive_operation_types on operation_types ot  (cost=0.15..63.50 rows=645 width=2)"
# "                                          Filter: (NOT is_virtual)"
# "                            ->  Sort  (cost=67.43..67.44 rows=3 width=42)"
# "                                  Sort Key: ho.block_num, ho.trx_in_block"
# "                                  ->  Append  (cost=4.23..67.41 rows=3 width=42)"
# "                                        ->  Bitmap Heap Scan on operations ho  (cost=4.23..12.75 rows=2 width=42)"
# "                                              Recheck Cond: ((block_num >= 1100) AND (block_num <= 1100) AND (block_num >= 1100) AND (block_num <= 1100))"
# "                                              Filter: (op_type_id <= $6)"
# "                                              ->  Bitmap Index Scan on hive_operations_block_num_trx_in_block_idx  (cost=0.00..4.23 rows=5 width=0)"
# "                                                    Index Cond: ((block_num >= 1100) AND (block_num <= 1100) AND (block_num >= 1100) AND (block_num <= 1100))"
# "                                        ->  Subquery Scan on ""*SELECT* 2_3""  (cost=44.56..54.65 rows=1 width=42)"
# "                                              ->  Nested Loop  (cost=44.56..54.64 rows=1 width=60)"
# "                                                    Join Filter: ((o.block_num = hbr_3.num) AND (o.fork_id = (max(hbr_3.fork_id))))"
# "                                                    ->  Index Scan using hive_operations_reversible_block_num_type_id_trx_in_block_fork_ on operations_reversible o  (cost=0.15..8.23 rows=1 width=50)"
# "                                                          Index Cond: ((block_num >= 1100) AND (block_num <= 1100) AND (block_num >= 1100) AND (block_num <= 1100) AND (op_type_id <= $6))"
# "                                                    ->  HashAggregate  (cost=44.41..44.98 rows=57 width=12)"
# "                                                          Group Key: hbr_3.num"
# "                                                          InitPlan 8 (returns $7)"
# "                                                            ->  Seq Scan on irreversible_data hid_4  (cost=0.00..32.00 rows=2200 width=4)"
# "                                                          ->  Seq Scan on blocks_reversible hbr_3  (cost=0.00..12.12 rows=57 width=12)"
# "                                                                Filter: (num > $7)"
# "                ->  GroupAggregate  (cost=93.65..93.84 rows=4 width=64)"
# "                      Group Key: txd.trx_hash"
# "                      ->  Sort  (cost=93.65..93.70 rows=18 width=64)"
# "                            Sort Key: txd.trx_hash"
# "                            ->  Hash Right Join  (cost=0.13..93.27 rows=18 width=64)"
# "                                  Hash Cond: (htm.trx_hash = txd.trx_hash)"
# "                                  ->  Append  (cost=0.00..89.66 rows=881 width=64)"
# "                                        ->  Seq Scan on transactions_multisig htm  (cost=0.00..18.80 rows=880 width=64)"
# "                                        ->  Subquery Scan on ""*SELECT* 2_4""  (cost=46.55..66.46 rows=1 width=64)"
# "                                              ->  Nested Loop  (cost=46.55..66.45 rows=1 width=64)"
# "                                                    Join Filter: (forks_2.max_fork_id = htmr.fork_id)"
# "                                                    ->  Hash Join  (cost=46.41..66.16 rows=1 width=48)"
# "                                                          Hash Cond: ((htr_1.fork_id = forks_2.max_fork_id) AND (htr_1.block_num = forks_2.num))"
# "                                                          ->  Seq Scan on transactions_reversible htr_1  (cost=0.00..16.40 rows=640 width=44)"
# "                                                          ->  Hash  (cost=45.55..45.55 rows=57 width=12)"
# "                                                                ->  Subquery Scan on forks_2  (cost=44.41..45.55 rows=57 width=12)"
# "                                                                      ->  HashAggregate  (cost=44.41..44.98 rows=57 width=12)"
# "                                                                            Group Key: hbr_4.num"
# "                                                                            InitPlan 6 (returns $5)"
# "                                                                              ->  Seq Scan on irreversible_data hid_3  (cost=0.00..32.00 rows=2200 width=4)"
# "                                                                            ->  Seq Scan on blocks_reversible hbr_4  (cost=0.00..12.12 rows=57 width=12)"
# "                                                                                  Filter: (num > $5)"
# "                                                    ->  Index Only Scan using pk_transactions_multisig_reversible on transactions_multisig_reversible htmr  (cost=0.15..0.27 rows=1 width=72)"
# "                                                          Index Cond: ((trx_hash = htr_1.trx_hash) AND (fork_id = htr_1.fork_id))"
# "                                  ->  Hash  (cost=0.08..0.08 rows=4 width=32)"
# "                                        ->  CTE Scan on trx_details txd  (cost=0.00..0.08 rows=4 width=32)"
# "  ->  Sort  (cost=0.32..0.35 rows=9 width=254)"
# "        Sort Key: bbd.num"
# "        ->  CTE Scan on base_blocks_data bbd  (cost=0.00..0.18 rows=9 width=254)"
# "  ->  Sort  (cost=0.03..0.04 rows=1 width=68)"
# "        Sort Key: ftws.block_num"
# "        ->  CTE Scan on full_transactions_with_signatures ftws  (cost=0.00..0.02 rows=1 width=68)"

# code in DO BEGIN END block:

# DO $$DECLARE
# 	_block_num_start INT := 1100;
# 	_block_count INT := 1;
# 	_result hive.block_type_ext;
# BEGIN
#         WITH
#         -- hive.get_block_from_views
#         base_blocks_data AS MATERIALIZED (
#             SELECT
#                 hb.num,
#                 hb.prev,
#                 hb.created_at,
#                 hb.transaction_merkle_root,
#                 hb.witness_signature,
#                 COALESCE(hb.extensions,  array_to_json(ARRAY[] :: INT[]) :: JSONB) AS extensions,
#                 hb.producer_account_id,
#                 hb.hash,
#                 hb.signing_key,
#                 ha.name
#             FROM hive.blocks_view hb
#             JOIN hive.accounts_view ha ON hb.producer_account_id = ha.id
#             WHERE hb.num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
#             ORDER BY hb.num ASC
#         ),
#         trx_details AS MATERIALIZED (
#             SELECT
#                 htv.block_num,
#                 htv.trx_in_block,
#                 htv.expiration,
#                 htv.ref_block_num,
#                 htv.ref_block_prefix,
#                 htv.trx_hash,
#                 htv.signature
#             FROM hive.transactions_view htv
#             WHERE htv.block_num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
#             ORDER BY htv.block_num ASC, htv.trx_in_block ASC
#         ),
#         operations AS (
#                 SELECT ho.block_num, ho.trx_in_block, ARRAY_AGG(ho.body ORDER BY op_pos ASC) bodies
#                 FROM hive.operations_view ho
#                 WHERE
#                     ho.op_type_id <= (SELECT ot.id FROM hive.operation_types ot WHERE ot.is_virtual = FALSE ORDER BY ot.id DESC LIMIT 1)
#                     AND ho.block_num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
#                 GROUP BY ho.block_num, ho.trx_in_block
#                 ORDER BY ho.block_num ASC, trx_in_block ASC
#         ),
#         full_transactions_with_signatures AS MATERIALIZED (
#                 SELECT
#                     htv.block_num,
#                     ARRAY_AGG(htv.trx_hash ORDER BY htv.trx_in_block ASC) AS trx_hashes,
#                     ARRAY_AGG(
#                         (
#                             htv.ref_block_num,
#                             htv.ref_block_prefix,
#                             htv.expiration,
#                             ops.bodies,
#                             array_to_json(ARRAY[] :: INT[]) :: JSONB,
#                             (
#                                 CASE
#                                     WHEN multisigs.signatures = ARRAY[NULL]::BYTEA[] THEN ARRAY[ htv.signature ]::BYTEA[]
#                                     ELSE htv.signature || multisigs.signatures
#                                 END
#                             )
#                         ) :: hive.transaction_type
#                         ORDER BY htv.trx_in_block ASC
#                     ) AS transactions
#                 FROM
#                 (
#                     SELECT txd.trx_hash, ARRAY_AGG(htmv.signature) AS signatures
#                     FROM trx_details txd
#                     LEFT JOIN hive.transactions_multisig_view htmv
#                     ON txd.trx_hash = htmv.trx_hash
#                     GROUP BY txd.trx_hash
#                 ) AS multisigs
#                 JOIN trx_details htv ON htv.trx_hash = multisigs.trx_hash
#                 JOIN operations ops ON ops.block_num = htv.block_num AND htv.trx_in_block = ops.trx_in_block
#                 WHERE ops.block_num BETWEEN _block_num_start AND ( _block_num_start + _block_count - 1 )
#                 GROUP BY htv.block_num
#                 ORDER BY htv.block_num ASC
#         )
#         SELECT INTO _result
#             bbd.num,
#             (
#                 bbd.prev,
#                 bbd.created_at,
#                 bbd.name,
#                 bbd.transaction_merkle_root,
#                 bbd.extensions,
#                 bbd.witness_signature,
#                 ftws.transactions,
#                 bbd.hash,
#                 bbd.signing_key,
#                 ftws.trx_hashes
#             ) :: hive.block_type
#         FROM base_blocks_data bbd
#         LEFT JOIN full_transactions_with_signatures ftws ON ftws.block_num = bbd.num
#         ORDER BY bbd.num ASC
#         ;
# END$$;


# blocks with nonzero revision in major.minor.revision:


# "num"	"hash"	"prev"	"created_at"	"producer_account_id"	"transaction_merkle_root"	"extensions"	"witness_signature"	"signing_key"	"hbd_interest_rate"	"total_vesting_fund_hive"	"total_vesting_shares"	"total_reward_fund_hive"	"virtual_supply"	"current_supply"	"current_hbd_supply"	"dhf_interval_ledger"
# 2726331	"binary data"	"binary data"	"2016-06-28 07:37:39"	219	"binary data"	"[{""type"": ""version"", ""value"": ""0.5.0""}, {""type"": ""hardfork_version_vote"", ""value"": {""hf_time"": ""1971-04-18T04:59:36"", ""hf_version"": ""0.0.489""}}]"	"binary data"	"STM7UiohU9S9Rg9ukx5cvRBgwcmYXjikDa4XM4Sy1V9jrBB7JzLmi"	1000	77422574172	428628195798690218	5452662000	84061384000	84061384000	0	0
# 2730591	"binary data"	"binary data"	"2016-06-28 11:10:54"	1495	"binary data"	"[{""type"": ""version"", ""value"": ""0.5.0""}, {""type"": ""hardfork_version_vote"", ""value"": {""hf_time"": ""1971-04-18T04:59:36"", ""hf_version"": ""0.0.118""}}]"	"binary data"	"STM89KiUX8J2QJJcU3EP49LPjsEzQhkNgjQHwhjteitPcH4XBRNaJ"	1000	77545609380	428662381238903833	5461182000	84191224000	84191224000	0	0
# 2733423	"binary data"	"binary data"	"2016-06-28 13:34:27"	1208	"binary data"	"[{""type"": ""version"", ""value"": ""0.5.0""}, {""type"": ""hardfork_version_vote"", ""value"": {""hf_time"": ""1970-07-04T15:27:12"", ""hf_version"": ""0.0.119""}}]"	"binary data"	"STM5AS7ZS33pzTf1xbTi8ZUaUeVAZBsD7QXGrA51HvKmvUDwVbFP9"	1000	77625174774	428672906660621845	5466846000	84277514000	84277514000	0	0
# 2768535	"binary data"	"binary data"	"2016-06-29 19:14:36"	4284	"binary data"	"[{""type"": ""version"", ""value"": ""0.5.0""}, {""type"": ""hardfork_version_vote"", ""value"": {""hf_time"": ""2004-02-17T01:16:32"", ""hf_version"": ""0.0.116""}}]"	"binary data"	"STM72ZRPaBjxtrEyNx7TsXvFp36FHV49M2qWE4tuSCUBxGnYBUeBZ"	1000	78617105734	428831186635035175	5537070000	85347594000	85347594000	0	0
# 2781318	"binary data"	"binary data"	"2016-06-30 05:57:33"	4284	"binary data"	"[{""type"": ""version"", ""value"": ""0.5.0""}, {""type"": ""hardfork_version_vote"", ""value"": {""hf_time"": ""2004-02-17T01:16:32"", ""hf_version"": ""0.0.116""}}]"	"binary data"	"STM72ZRPaBjxtrEyNx7TsXvFp36FHV49M2qWE4tuSCUBxGnYBUeBZ"	1000	78980699708	428901895503952929	5562636000	85737154000	85737154000	0	0
# 2786287	"binary data"	"binary data"	"2016-06-30 10:07:33"	4948	"binary data"	"[{""type"": ""version"", ""value"": ""0.5.0""}, {""type"": ""hardfork_version_vote"", ""value"": {""hf_time"": ""1971-04-20T07:30:16"", ""hf_version"": ""0.0.119""}}]"	"binary data"	"STM6sCWywrNY4zt5aVoazSeWb3gc8C7Qr68btVmb1hq92ftbm2reX"	1000	79123595976	428937558148357228	5572574000	85888624000	85888624000	0	0


# w block logu jest forma spakowana z pamięciowej (pozbawioonej luk w pamieci)

# 2 wersje spakowane transakcje
#     asset symbol w formie legacy 8 bajtow
#     albo nai 4 bajty


# forma spakowana jest podpisywana




###### list_15_richest_accounts.py ######
# import urllib.request
# import json



# first_account_name = b""

# accounts_list = []

# while True:

#     req = urllib.request.Request(url='http://localhost:8091',
#                          data=b'{"jsonrpc":"2.0", "method":"database_api.list_accounts", "params": {"start":"' +  first_account_name + b'", "limit":100, "order":"by_name"}, "id":1}')

#     with urllib.request.urlopen(req) as f:
#         json_string = f.read().decode('utf-8')

#     json_object = json.loads(json_string)

#     accounts = json_object["result"]["accounts"]
    
#     for i, account in enumerate(accounts):
#         if i != (len(accounts) - 1):
#             accounts_list.append((account["name"], int(account["balance"]["amount"]), int(account["hbd_balance"]["amount"]) ,  int(account["vesting_shares"]["amount"]) ))

#     if len(accounts) > 1:
#         last_account = accounts[-1]
#         first_account_name =  last_account["name"]
#         first_account_name = str.encode(first_account_name)
#     else:
#         break

# accounts_list.sort(key = lambda x: x[1], reverse=True)

# for i in range (15):
#     print(accounts_list[i])

# after /home/haf_admin/build/hive/programs/hived/hived --blockchain-thread-pool-size=1 --data-dir=/home/hived/datadir --replay --force-replayy --stop-replay-at-block=100000 --p2p-endpoint=0.0.0.0:2001 --webserver-http-endpoint=0.0.0.0:8090 --webserver-ws-endpoint=0.0.0.0:8091
# I get:
# haf_admin@261a1ebca8b7:~$ python3 /home/haf_admin/haf/scripts/15richest.py
# ('any', 2236000, 0, 1000000)
# ('steemit1', 2083000, 0, 1000000)
# ('moderator', 2052000, 0, 1000000)
# ('steemit10', 1991000, 0, 1000000)
# ('steemit11', 1923000, 0, 1000000)
# ('steemit12', 1830000, 0, 1000000)
# ('steemit13', 1775000, 0, 1000000)
# ('steemit', 1756000, 0, 3701000000)
# ('root', 1752000, 0, 1000000)
# ('steemit17', 1713000, 0, 1000000)
# ('steemit15', 1712000, 0, 1000000)
# ('steemit20', 1702000, 0, 1000000)
# ('steemit18', 1669000, 0, 1000000)
# ('sminer10', 1637000, 0, 1000000)
# ('administrator', 1618000, 0, 1000000)

#and  after ~$ /home/haf_admin/build/hive/programs/hived/hived --blockchain-thread-pool-size=1 --data-dir=/home/hived/datadir --replay  --stop-replay-at-block=5000000 --p2p-endpoint=0.0.0.0:2001 --webserver-http-endpoint=0.0.0.0:8090 --webserver-ws-endpoint=0.0.0.0:8091 --plugin=database_api
# we have:
#  python3 /home/haf_admin/haf/scripts/15richest.py
# ('steemit', 4778859891, 70337438, 225671901920188893)
# ('poloniex', 1931250425, 158946758, 4404577000000)
# ('bittrex', 499025114, 81920425, 4404642000000)
# ('steemit2', 197446682, 106543552, 5213443854825)
# ('aurel', 97417738, 1457, 47962153427941)
# ('openledger', 52275479, 18607380, 11850514000000)
# ('ben', 50968139, 1415, 6599654505904881)
# ('blocktrades', 29594875, 77246982, 8172549681941451)
# ('steem', 29315310, 500001, 15636871956265)
# ('imadev', 23787999, 117353589, 445256469401562)
# ('smooth', 20998219, 599968, 6261692171889459)
# ('steemit60', 20000000, 31005142, 1000000000000)
# ('taker', 15014283, 535515, 4596963565191)
# ('steemit1', 10000205, 134872472, 1005084292327)
# ('ashold882015', 9895158, 134, 3101147621378)

# Pattern 23645964
# ('bittrex', 22319508517, 9982418381, 8546709372209)
# ('poloniex', 14479958335, 472131272, 4404577000000)
# ('binance-hot', 8183911450, 3680, 1023055299)
# ('huobi-withdrawal', 2963571300, 3, 4079848926560)
# ('steemit2', 2279627277, 4992071, 97494724537487)
# ('ben', 2213971486, 929, 659751021)
# ('imadev', 788297714, 452, 445256469401562)
# ('openledger-dex', 522742188, 40952501, 1033789880)
# ('upbit-exchange', 477889426, 608800589, 10236655591659)
# ('dan', 471203861, 427118, 58822357508745)
# ('muchfun', 415000004, 103, 12360924266)
# ('cdec84', 335009000, 0, 6093749649)
# ('dantheman', 300198008, 98623, 212148717653)
# ('amcq', 290000001, 263989, 8808070581)
# ('alpha', 272174106, 10328619, 82084887877)

# root" execution of the PostgreSQL server is not permitted.
# The server must be started under an unprivileged user ID to prevent
# possible system security compromise.  See the documentation for

# valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=./callgrind.out.%p /usr/lib/postgresql/14/bin/postgres --config_file=/etc/postgresql/14/main/postgresql.conf

# proby byly 
# 1. -static-libasan:
# SET(HIVE_ASAN_LINK_OPTIONS  -fsanitize=address)  -> SET(HIVE_ASAN_LINK_OPTIONS -static-libasan -fsanitize=address)

# 2. driver of postgres functions 
# src/hive_fork_manager/shared_lib/CMakeLists.txt:
# ADD_EXECUTABLE(consp_driver
    
#   mtlk_main.cpp
# )

# ADD_POSTGRES_INCLUDES( consp_driver )
# ADD_POSTGRES_LIBRARIES( consp_driver )

# target_link_libraries(consp_driver
#     PRIVATE ${target_name}
# )

#    src/hive_fork_manager/shared_lib/mtlk_main.cpp:

# #include "operation_base.hpp"

# #include <hive/protocol/forward_impacted.hpp>
# #include <hive/protocol/misc_utilities.hpp>

# #include <fc/io/json.hpp>
# #include <fc/string.hpp>

# #include <vector>



# #include "postgres.h"
# #include "fmgr.h"

# PG_FUNCTION_INFO_V1(consensus_state_provider_replay);

# Datum consensus_state_provider_replay(PG_FUNCTION_ARGS);



# int main()
# {
#     consensus_state_provider_replay();
#     return 0;
# }







BUILD_DIR=.
BUILD_DIR=$(realpath $BUILD_DIR)
SRC_DIR=../haf
DATA_DIR=/home/hived/datadir
# DATA_DIR=/home/dev/mainnet-5m



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
    cmake  -DCMAKE_BUILD_TYPE=Debug -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS=" -O0 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # Debug O0

    CMAKED=true

elif [[ "$PWD" =~ RelWithDebInfo_build$ ]]
then
    echo building RelWithDebInfo
    cmake  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-O0 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # RelWithDebInfo

    CMAKED=true

elif [[ "$PWD" =~ testnet_build$ ]]
then
    echo building testnet_build
    cmake  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_HIVE_TESTNET=ON -DCMAKE_CXX_FLAGS="-O0 -fdiagnostics-color=always" -GNinja $SRC_DIR ; # testnet_build

    CMAKED=true


elif [[ "$PWD" =~ build$ ]]
then

    cmake  -DCMAKE_BUILD_TYPE=Release -DBUILD_HIVE_TESTNET=OFF -DCMAKE_CXX_FLAGS="-fdiagnostics-color=always" -GNinja $SRC_DIR ;  # Release
    
   
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
    ninja query_supervisor hived extension.hive_fork_manager && sudo ninja install && sudo chown $USER:$USER .ninja_* # && ctest -R keyauth --output-on-failure # && ctest -R curr --output-on-failure 
    EXIT_STATUS=$?
    # ninja consp_driver; sudo chown $USER:$USER .ninja_*
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
    # preconditions for consp_driver
    if [ -d /home/hived/datadir/consensus_state_provider ]
    then
        echo /home/hived/datadir/consensus_state_provider Still there!
    fi

    psql -d haf_block_log -c 'select count(*) from hive.blocks'

    ./bin/consp_driver --to=$LAST_BLOCK

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
    ninja consp_driver query_supervisor hived extension.hive_fork_manager &&
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


# unit test:
# sudo -n /etc/init.d/postgresql restart ; sudo rm -rf /home/hived/datadir/consensus_unit_test_storage_dir; clearterm; ../haf/scripts/runallnow.sh 5000000 rebuild ; ctest -R curr --output-on-failure 

# driver:
# sudo rm -rf /home/hived/datadir/consensus_state_provider/ ; ../haf/scripts/runallnow.sh 2000000 driver_build_and_run 2> /home/hived/datadir/sbo.log 

# hived sync:
# (cd /home/haf_admin/.hived/blockchain && rm block_log.artifacts shared_memory.bin;  cp block_log_initial_copy block_log) && /home/haf_admin/build/hive/programs/hived/hived --replay

# hived tests:
# cd /home/haf_admin/testnet_build
# rm -rf *
# rm -rf .*
# cmake  -DCMAKE_BUILD_TYPE=Release   -DBUILD_HIVE_TESTNET=ON -GNinja ../haf
# ninja get_dev_key cli_wallet hived chain_test && \
# (cd ../haf/hive/tests/functional/python_tests/hf26_tests && pytest) || (exit $?) && \
# # (cd ../haf/hive/tests/functional/python_tests/foundation_layer_tests && pytest) || (exit $?) && \
# # ./hive/tests/unit/chain_test  --run_test=operation_tests || (exit $?) &&  \
# echo ok || echo notok


: <<'virtuals'

Directly using _block_log on the left:

DONE reindex_internal<-reindex
DONE reindex<-chain_plugin_impl::replay_blockchain
DONE is_reindex_complete<-chain_plugin_impl::check_data_consistency

DONE(wipe not needed) close<-*wipe
DONE close<-chain_plugin::plugin_shutdown

DONE is_known_block<-chain_plugin::block_is_on_preferred_chain
DONE is_known_block<-p2p_plugin_impl::has_item

DONE is_known_block_unlocked<-*find_first_item_not_in_blockchain
DONE *find_first_item_not_in_blockchain

DONE find_block_id_for_num<-*get_block_id_for_num
DONE *get_block_id_for_num

DONE fetch_block_range<-DEFINE_API_IMPL( block_api_impl, get_block_range )

fetch_block_by_number<-DEFINE_API_IMPL( account_history_api_rocksdb_impl, get_transaction )
fetch_block_by_number<-DEFINE_API_IMPL( block_api_impl, get_block_header )
fetch_block_by_number<-DEFINE_API_IMPL( block_api_impl, get_block )
fetch_block_by_number<-DEFINE_API_IMPL( debug_node_api_impl, debug_get_head_block )
fetch_block_by_number<-DEFINE_API_IMPL( transaction_status_api_impl, find_transaction )
fetch_block_by_number<-transaction_status_impl::get_earliest_transaction_in_range
fetch_block_by_number<-transaction_status_impl::get_latest_transaction_in_range
fetch_block_by_number<-transaction_status_impl::rebuild_state
DONE - process_optional_actions does not exist any more  fetch_block_by_number<-*process_optional_actions (process_optional_actions propagates to _apply_block)

DONE fetch_block_by_id<-*pop_block
DONE fetch_block_by_id<-p2p_plugin_impl::get_full_block
DONE fetch_block_by_id<-p2p_plugin_impl::get_block_time

migrate_irreversible_state<-*_apply_block
migrate_irreversible_state<-*process_fast_confirm_transaction

DONE get_blockchain_synopsis<-p2p_plugin_impl::get_blockchain_synopsis
DONE is_included_block_unlocked<-get_block_ids
DONE get_block_ids<-p2p_plugin_impl::get_block_ids

get_head_block<-*load_state_initial_data
open_block_log<-*initialize_state_independent_data

virtuals



: <<'launch_hived__in_sync_mode'


# debug block number in gdb: full_block->get_block().num_from_id(full_block->get_block_id()),d


launch.json
  {
            "name": "(gdb) DEBUG Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "/home/haf_admin/debug_build/hive/programs/hived/hived",
            "args": ["--replay"],
            "preLaunchTask" : "clean_dot_hived",
            "stopAtEntry": true,
            "cwd": "${fileDirname}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "Set Disassembly Flavor to Intel",
                    "text": "-gdb-set disassembly-flavor intel",
                    "ignoreFailures": true
                }
            ]
        }


tasks.json
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",
    "tasks": [
        {
            "label": "clean_dot_hived",
            "type": "shell",
            "command": "(cd /home/haf_admin/.hived/blockchain && rm block_log.artifacts shared_memory.bin;  cp block_log_initial_copy block_log)"
        }
    ]
}        
launch_hived__in_sync_mode
