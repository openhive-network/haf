#!/bin/bash

# sudo rm /home/hived/datadir/context/blockchain/shared_memory.bin; ../haf/scripts/runallnow.sh build

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

# mtlk TODO:
# TODO - bash_test assert
# TODO - recognize existing context_shared_memory_bin
# TODO why runall script has to clear contest sharedmemory.bin ?
# TODO cleanup init(db
# TODO example testing app
# TODO eliminate MTLK_FROM_VARIANT_ON_CONSUME_JSON_HACK
# TODO interface ?

# TODO clang find #include
$ TODO ?  add .clang-format 





# DONE start/stop on contextual shared mem file
# DONE What about ON CONFLICT DO NOTHING in src/hive_fork_manager/state_providers/current_account_balance.sql - two accounts in one state ?     texcik = format('INSERT INTO hive.%I SELECT * FROM hive.current_all_accounts_balances_C(%L) ON CONFLICT DO NOTHING;', __table_name, _context);
# DONE (minor gain )consuming jsons one by one or getting a vector of blocks form haf block api
# DONE separate C function to get current block_num where we stand
# TODO ? in yaml - cp log to . instead of ln -s
# TODO separate from database_api.cpp, database_api_plugin

# TODO //na krotkim blocklogu zobacz jak to push blok chodzi

# TODO ? lock na funckjach w C lub wyżej

# DONE (eliminated) is it needed ?         bfs::permissions(abs_path, b
# DONE (eliminated in favor of explicit parameter) better "PGDATA" get_context_data_dir() // //getenv("HAF_DB_STORE");//BLOCK_LOG_DIRECTORY
# TODO funkcja do zwracania + 'blockchain' 
# TODO test for many contexts
# DONE expected_block_num no global var

# TODO new db a nie ma delete , moze smart pointer ?
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



remove_context_shared_memory_bin()
{
    sudo rm  $DATA_DIR/context/blockchain/shared_memory.bin && echo removed! || echo not removed
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

if [ $# -eq 0 ]
  then
    run
else
    echo ">>>>>>Invoking $1 <<<<<<<<"
    $1
fi



