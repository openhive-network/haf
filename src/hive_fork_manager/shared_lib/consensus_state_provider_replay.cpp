


#include "fc/variant.hpp"
#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>

#include "hive/chain/database.hpp"
#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"
#include <iostream>
#include <pqxx/pqxx>

#include "hive/plugins/database_api/consensus_state_provider_cache.hpp"


namespace hive { namespace app {

std::shared_ptr<hive::chain::full_block_type> from_variant_to_full_block_ptr(const fc::variant& v, int block_num_debug );
}}

#ifdef HAF_SHARED_LIB

#pragma message ("HAF_SHARED_LIB defined !!! hey")

#endif





namespace hive { namespace app {


fc::path get_context_shared_data_bin_dir()
{

    fc::path data_dir;
    char* parent = getenv( "PGDATA" );

    system("env");

    if( parent != nullptr )
    {
      data_dir = std::string( parent );
      data_dir = data_dir.parent_path();
      data_dir = data_dir.parent_path();
    }
    return data_dir;
}

void sanity_check(const char *&postgres_url) 
{
    pqxx::connection c{postgres_url};
    pqxx::work txn{c};
    pqxx::result r{txn.exec("SELECT COUNT(*) FROM hive.blocks")};

    std::cout << "mtlk columns count=" << r.columns() << "\n";
    std::cout << "mtlk column name=" << r.column_name(0) << "\n";
    std::cout << "mtlk rows  count=" << r.size() << "\n";

    for (auto row : r)
      std::cout
          // Address column by name.  Use c_str() to get C-style string.
          << row["count"].c_str()
          << " makes "
          // Address column by zero-based index.  Use as<int>() to parse as int.
          << row[0].as<int>() << "." << std::endl;
    txn.commit();

  for(auto i = 0u; i < r.columns(); ++i)
  {
    std::cout << "Column " << i << " name=" << r.column_name(i) << " type= " << r.column_type(r.column_name(i)) << std::endl;
  }
}

std::string fixTime(const pqxx::field& t)
{
  std::string r =t.c_str();
  r[10] = 'T';
  return r;
}


const char* fixHex(const pqxx::field& h)
{
    return h.c_str() + 2;
}


#define MULTISIGS_IN_C


struct Postgres2Blocks
{



  pqxx::result blocks;
  pqxx::result transactions;
  pqxx::result operations;
  std::multimap<std::string, std::string> multisigs;

  int transaction_expecting_block;
  pqxx::result::const_iterator transactions_it;
  int operations_expecting_block;
  int operations_expecting_transaction;
  pqxx::result::const_iterator operations_it;


void get_data_from_postgres(int from, int to, const char* postgres_url)
{
  pqxx::connection c{postgres_url};

  pqxx::work blocks_work{c};
  blocks = {blocks_work.exec("SELECT * FROM hive.blocks JOIN hive.accounts ON  id = producer_account_id WHERE num >= " 
                            + std::to_string(from) 
                            + " and num <= " 
                            + std::to_string(to) 
                            + " ORDER BY num ASC")};
  blocks_work.commit();

  pqxx::work transactions_work{c};
  transactions = {transactions_work.exec("SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix, expiration, trx_hash, signature FROM hive.transactions WHERE block_num >= " 
                            + std::to_string(from) 
                            + " and block_num <= " 
                            + std::to_string(to) 
                            + " ORDER BY block_num, trx_in_block ASC")};
  transactions_work.commit();


  pqxx::work operations_work{c};
  operations = {operations_work.exec("SELECT block_num, body, trx_in_block FROM hive.operations WHERE block_num >= " 
                            + std::to_string(from) 
                            + " and block_num <= " 
                            + std::to_string(to) 
                            + " AND op_type_id <= 49 "
                            + " ORDER BY id ASC")};
  operations_work.commit();



#ifdef MULTISIGS_IN_C

  // pqxx::work transactions_multisig_work{c};
  // pqxx::result transactions_multisig{
  //   transactions_multisig_work.exec(
  //     std::string("SELECT trx_hash,signature FROM hive.transactions_multisig"))};


  // for( auto row : transactions_multisig)
  // {
  //   std::string key(std::string(row["trx_hash"].c_str()+2));
  //   multisigs.insert(std::make_pair(key, row["signature"].c_str()+2));
  // }

  // transactions_multisig_work.commit();

#endif

}

void prepare_iterators()
{
  transaction_expecting_block = -1;
  transactions_it = transactions.begin();
  if( transactions.size() > 0)
  {
      const auto& first_transaction = transactions[0];
      transaction_expecting_block = first_transaction["block_num"].as<int>();
  }

  operations_expecting_block = -1;
  operations_expecting_transaction = -1;
  operations_it = operations.begin();
  if(operations.size() > 0)
  {
    const auto& first_operation = operations[0];
    operations_expecting_block =  first_operation["block_num"].as<int>();
    operations_expecting_transaction = first_operation["trx_in_block"].as<int>();

  }
}

void handle_operations(int block_num, int trx_in_block, std::vector<fc::variant>& operations_vector)
{
  for(; operations_it != operations.end(); ++operations_it)
  {
    const auto operation = (*operations_it);
    if(operation["block_num"].as<int>() == block_num && operation["trx_in_block"].as<int>() == trx_in_block)
    {
      // fill in op here

      const auto &o = operation["body"];
      std::string json = std::string(o.c_str());
      fc::variant ov = fc::json::from_string(json);

      hive::protocol::operation op;
      fc::from_variant(ov, op);

      operations_vector.push_back(ov);
    }
    else
    {
      operations_expecting_block = operations_it["block_num"].as<int>();
      operations_expecting_transaction =
          operations_it["trx_in_block"].as<int>();
      break;
    }
  }
}
void handle_transactions(int block_num, 
  std::vector<variant>& transaction_ids_vector,
  std::vector<fc::variant>& trancactions_vector)
 {
  for (; transactions_it != transactions.end(); ++transactions_it) {
    const auto transaction = (*transactions_it);
    if (transaction["block_num"].as<int>() == block_num) {
      auto trx_in_block = transaction["trx_in_block"].as<int>();

      // fill in transaction here
      std::vector<std::string> signa;
      if (strlen(transaction["signature"].c_str())) {
        signa.push_back(transaction["signature"].c_str() + 2);

#ifndef MULTISIGS_IN_C
        pqxx::work transactions_multisig_work{c};
        pqxx::result transactions_multisig{transactions_multisig_work.exec(
            std::string("SELECT signature FROM hive.transactions_multisig "
                        "WHERE trx_hash  = '") +
            (transaction["trx_hash"].c_str()) + "'")};

        for (auto row : transactions_multisig) {
          signa.push_back(row["signature"].c_str() + 2);
        }

        transactions_multisig_work.commit();
#else
        // auto range = multisigs.equal_range(transaction["trx_hash"].c_str() + 2);
        // for (auto it = range.first; it != range.second; ++it) {
        //   signa.push_back(it->second);
        // }
#endif
      }

      fc::variant_object_builder transaction_v;
      transaction_v("ref_block_num", transaction["ref_block_num"].as<int>())(
          "ref_block_prefix", transaction["ref_block_prefix"].as<int64_t>())(
          "expiration", fixTime(transaction["expiration"]))("signatures", signa);

      transaction_ids_vector.push_back(transaction["trx_hash"].c_str() + 2);


      // rewind
      while (operations_expecting_block < block_num) {
        operations_it++;
        operations_expecting_block = operations_it["block_num"].as<int>();
        operations_expecting_transaction =
            operations_it["trx_in_block"].as<int>();
      }

      std::vector<fc::variant> operations_vector;
      if(block_num == operations_expecting_block && trx_in_block == operations_expecting_transaction)
        handle_operations(block_num, trx_in_block, operations_vector);


      transaction_v("operations", operations_vector);

      variant tv;
      to_variant(transaction_v.get(), tv);
      trancactions_vector.push_back(tv);

    } else {
      transaction_expecting_block = transaction["block_num"].as<int>();
      break;
    }
  }
}


fc::variant block2variant(const pqxx::row& block)
{
  auto block_num = block["num"].as<int>();

  std::vector<variant> transaction_ids_variants;
  std::vector<fc::variant> transaction_variants;
  if(block_num == transaction_expecting_block)
    handle_transactions(block_num, transaction_ids_variants, transaction_variants);

  std::string json = block["extensions"].c_str();
  variant extensions = fc::json::from_string(json.empty() ?"[]":json);

  // fill in block header here
  fc::variant_object_builder block_variant_builder; 
  block_variant_builder
  ("witness", block["name"].c_str())
  ("block_id", fixHex(block["hash"]))
  ("previous", fixHex(block["prev"]))
  ("timestamp", fixTime(block["created_at"]))
  ("extensions", extensions)
  ("signing_key", block["signing_key"].c_str())
  ("transactions", transaction_variants)
  ("witness_signature", fixHex(block["witness_signature"]))
  ("transaction_merkle_root", fixHex(block["transaction_merkle_root"]))
  ("transaction_ids", transaction_ids_variants);

  variant block_variant;
  to_variant(block_variant_builder.get(), block_variant);
  return block_variant;
}

void blocks2replay(const char *context)
{


 for(const auto& block : blocks)
  {
    fc::variant v = block2variant(block);

    auto block_num = block["num"].as<int>();

    //std::string json = fc::json::to_pretty_string(v);
    //wlog("block_num=${block_num} header=${j}", ("block_num", block_num) ( "j", json));

    int n = consume_variant_block_impl(v, context, block_num);
    n=n;
  }
}

void run(int from, int to, const char *context, const char *postgres_url) 
{
  get_data_from_postgres(from, to, postgres_url);

  prepare_iterators();
  
  blocks2replay(context);
}

};

void consensus_state_provider_replay_impl(int from, int to, const char *context,
                                const char *postgres_url) 
{
  sanity_check(postgres_url);

  Postgres2Blocks p2b;
  p2b.run(from, to, context, postgres_url); 
}



}}



void init(hive::chain::database& db, const char* context)
{


  db.set_flush_interval( 10'000 );//10 000
  db.set_require_locking( false );// false 


  hive::chain::open_args db_open_args;
  db_open_args.data_dir = "/home/dev/mainnet-5m";
  db_open_args.data_dir = "/home/dev/.consensus_state_provider";


  db_open_args.data_dir = hive::app::get_context_shared_data_bin_dir();
  ilog("mtlk db_open_args.data_dir=${dd}",("dd", db_open_args.data_dir));

  db_open_args.shared_mem_dir =  db_open_args.data_dir /  "blockchain"; // "/home/dev/mainnet-5m/blockchain"
  db_open_args.initial_supply = HIVE_INIT_SUPPLY; // 0
  db_open_args.hbd_initial_supply = HIVE_HBD_INIT_SUPPLY;// 0

  db_open_args.shared_file_size = 25769803776;  //my->shared_memory_size = fc::parse_size( options.at( "shared-file-size" ).as< string >() );

  db_open_args.shared_file_full_threshold = 0;// 0
  db_open_args.shared_file_scale_rate = 0;// 0
  db_open_args.chainbase_flags = 0;// 0
  db_open_args.do_validate_invariants = false; // false
  db_open_args.stop_replay_at = 0;//0
  db_open_args.exit_after_replay = false;//false
  db_open_args.validate_during_replay = false;// false
  db_open_args.benchmark_is_enabled = false;//false
  db_open_args.replay_in_memory = false;// false
  db_open_args.enable_block_log_compression = true;// true
  db_open_args.block_log_compression_level = 15;// 15

  db_open_args.postgres_not_block_log = true;

  db_open_args.force_replay = false;// false

  db.open( db_open_args, context );

}



int initialize_context(const char* context)
{
  if(!consensus_state_provider::get_cache().has_context(context))
  {
    hive::chain::database* db = new hive::chain::database;
    init(*db, context);
    consensus_state_provider::get_cache().add(context, *db);
    //haf_database_api_impls.emplace(std::make_pair(std::string(context), hive::plugins::database_api::database_api_impl(*db)));
    return db->head_block_num() + 1;
  }
  else
  {
    
    hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
    return db.head_block_num() + 1;
  }
}


namespace hive { namespace app {
int consume_variant_block_impl(const fc::variant& v, const char* context, int block_num)
{

  static auto first_time = true;
  if(first_time)
  {
    first_time = false;
    wlog("mtlk consume_variant_block_impl pid= ${pid}", ("pid", getpid()));
  }

  int expected_block_num = initialize_context(context);

  if(block_num != expected_block_num)
     return expected_block_num;

  expected_block_num++;


  hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
  

  

 
  std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_variant_to_full_block_ptr(v, block_num);

  

  uint64_t skip_flags = chain::database::skip_block_log;
  // skip_flags |= hive::plugins::chain::database::skip_validate_invariants;
  
  //skip_flags |= hive::plugins::chain::database::skip_witness_signature ; //try not to skip it mtlk 
  // skip_flags |= hive::plugins::chain::database::skip_transaction_signatures;
  // skip_flags |= hive::plugins::chain::database::skip_transaction_dupe_check;
  //skip_flags |= hive::plugins::chain::database::skip_tapos_check; //try not to skip it mtlk 
  //skip_flags |= hive::plugins::chain::database::skip_merkle_check;//try not to skip it mtlk 
  // skip_flags |= hive::plugins::chain::database::skip_witness_schedule_check;
  //skip_flags |= hive::plugins::chain::database::skip_authority_check;//try not to skip it mtlk 
  // skip_flags |= hive::plugins::chain::database::skip_validate;



      skip_flags |= chain::database::skip_witness_signature |
      chain::database::skip_transaction_signatures |
      chain::database::skip_transaction_dupe_check |
      chain::database::skip_tapos_check |
      chain::database::skip_merkle_check |
      chain::database::skip_witness_schedule_check |
      chain::database::skip_authority_check |
      chain::database::skip_validate; /// no need to validate operations


  db.set_tx_status( chain::database::TX_STATUS_BLOCK );


  db.public_apply_block(fb_ptr, skip_flags);

  db.clear_tx_status();



  db.set_revision( db.head_block_num() );


  return expected_block_num;
}
}}


namespace hive { namespace app {
int consensus_state_provider_get_expected_block_num_impl(const char* context)
{
  return initialize_context(context);
}
}}

namespace hive { namespace app {
void consensus_state_provider_finish_impl(const char* context)
{
  if(consensus_state_provider::get_cache().has_context(context))
  {
      hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
      db.close();
      db. chainbase::database::wipe( get_context_shared_data_bin_dir()  /  "blockchain" , context);
      consensus_state_provider::get_cache().remove(context);

  }
}
}}
