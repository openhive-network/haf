#include "consensus_state_provider_replay.hpp"

#include "fc/variant.hpp"
#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>

#include "hive/chain/database.hpp"
#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"
#include <limits>
#include <pqxx/pqxx>

#include "hive/plugins/database_api/consensus_state_provider_cache.hpp"
#include "from_variant_to_full_block_ptr.hpp"


namespace consensus_state_provider
{

// value coming from pxx is without 'T' in the middle to be accepted in variant
std::string fix_pxx_time(const pqxx::field& t)
{
  std::string r =t.c_str();
  r[10] = 'T';
  return r;
}

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h)
{
    return h.c_str() + 2;
}


class PostgresDatabase 
{
public:
 PostgresDatabase(const char* url) : conn(url) 
 {}

 pqxx::result execute_query(const std::string& query)
 {
   pqxx::work txn(conn);
   pqxx::result res = txn.exec(query);
   txn.commit();
   return res;
 }

private:
    pqxx::connection conn;
};

struct Postgres2Blocks
{
  //values taken from database
  pqxx::result blocks;
  pqxx::result transactions;
  pqxx::result operations;

  //iterators for traversing the values above
  int current_transaction_block_num() 
  { 
    if(transactions.empty())
      return -1;
    if(transactions.end() == current_transaction)
      return std::numeric_limits<int>::max();
    return current_transaction["block_num"].as<int>(); 
    }

  pqxx::result::const_iterator current_transaction;

  int current_operation_block_num() const 
  { 
    if(operations.empty())
      return -1;
    if(operations.end() == current_operation)
      return std::numeric_limits<int>::max();
    return current_operation["block_num"].as<int>(); 
  }

  int current_operation_trx_num() const { 
    if(operations.empty())
      return -1;
    if(operations.end() == current_operation)
      return std::numeric_limits<int>::max();
    return current_operation["trx_in_block"].as<int>(); 
  }

  pqxx::result::const_iterator current_operation;

  void get_data_from_postgres(int from, int to, const char* postgres_url)
  {
   PostgresDatabase db(postgres_url);

    auto blocks_query = "SELECT * FROM hive.blocks JOIN hive.accounts ON  id = producer_account_id WHERE num >= " 
                                + std::to_string(from) 
                                + " and num <= " 
                                + std::to_string(to) 
                                + " ORDER BY num ASC";
   blocks = db.execute_query(blocks_query);

    auto transactions_query = "SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix, expiration, trx_hash, signature FROM hive.transactions WHERE block_num >= " 
                                + std::to_string(from) 
                                + " and block_num <= " 
                                + std::to_string(to) 
                                + " ORDER BY block_num, trx_in_block ASC";
   transactions = db.execute_query(transactions_query);

    auto operations_query = "SELECT block_num, body, trx_in_block FROM hive.operations WHERE block_num >= " 
                                + std::to_string(from) 
                                + " and block_num <= " 
                                + std::to_string(to) 
                                + " AND op_type_id <= 49 "
                                + " ORDER BY id ASC";
   operations = db.execute_query(operations_query);
}

void initialize_iterators()
{
  current_transaction = transactions.begin();
  current_operation = operations.begin();
}


bool operation_matches_block_transaction(const pqxx::const_result_iterator& operation, int block_num, int trx_in_block) 
{
    return operation["block_num"].as<int>() == block_num && operation["trx_in_block"].as<int>() == trx_in_block;
}


void add_operation_variant(const pqxx::const_result_iterator& operation, std::vector<fc::variant>& operations_variants)
{
    const auto& body_in_json = operation["body"].c_str();
    const auto& operation_variant = fc::json::from_string(body_in_json);
    operations_variants.emplace_back(operation_variant);
}


std::vector<fc::variant> operations2variants(int block_num, int trx_in_block)
{
  std::vector<fc::variant> operations_variants;
  if(is_current_operation(block_num, trx_in_block))
  {
    for(; current_operation != operations.end() && operation_matches_block_transaction(current_operation, block_num, trx_in_block); ++current_operation)
    {
      add_operation_variant(current_operation, operations_variants);
    }
  }
  return operations_variants;
}

bool is_current_operation(int block_num, int trx_in_block) const 
{
  return block_num == current_operation_block_num() && trx_in_block == current_operation_trx_num();
}


bool is_current_transaction(const pqxx::result::const_iterator& current_transaction, const int block_num)
{
    return current_transaction["block_num"].as<int>() == block_num;
}

void transactions2variants(int block_num, std::vector<fc::variant>& transaction_id_variants, std::vector<fc::variant>& trancaction_variants)
{
  for(; current_transaction != transactions.end() && is_current_transaction(current_transaction, block_num); ++current_transaction)
  {
    auto trx_in_block = current_transaction["trx_in_block"].as<int>();

    std::vector<std::string> signatures = build_signatures(current_transaction);

    build_transaction_ids(current_transaction, transaction_id_variants);

    rewind_operations_iterator_to_current_block(block_num);

    std::vector<fc::variant> operations_variants = operations2variants(block_num, trx_in_block);

    fc::variant transaction_variant = build_transaction_variant(current_transaction, signatures, operations_variants);

    trancaction_variants.emplace_back(transaction_variant);
  }
}


void build_transaction_ids(const pqxx::result::const_iterator& transaction, std::vector<fc::variant>& transaction_id_variants)
{
  transaction_id_variants.push_back(fix_pxx_hex(transaction["trx_hash"]));
}

std::vector<std::string> build_signatures(const pqxx::result::const_iterator& transaction) 
{
  std::vector<std::string> signatures;
  if (strlen(transaction["signature"].c_str())) 
  {
    signatures.push_back(fix_pxx_hex(transaction["signature"]));
  }
  return signatures;
}

void rewind_operations_iterator_to_current_block(int block_num)
{
  while (current_operation_block_num() < block_num && current_operation != operations.end())
  {
    ++current_operation;
  }
}

fc::variant build_transaction_variant(const pqxx::result::const_iterator& transaction, const std::vector<std::string>& signatures, const std::vector<fc::variant>& operations_variants)
{
  fc::variant_object_builder transaction_variant_builder;
  transaction_variant_builder
    ("ref_block_num", transaction["ref_block_num"].as<int>())
    ("ref_block_prefix", transaction["ref_block_prefix"].as<int64_t>())
    ("expiration", fix_pxx_time(transaction["expiration"]))
    ("signatures", signatures)
    ("operations", operations_variants);

  return transaction_variant_builder.get();
}




fc::variant block2variant(const pqxx::row& block)
{
  auto block_num = block["num"].as<int>();

  std::vector<fc::variant> transaction_ids_variants;
  std::vector<fc::variant> transaction_variants;
  if(block_num == current_transaction_block_num())
    transactions2variants(block_num, transaction_ids_variants, transaction_variants);

  std::string json = block["extensions"].c_str();
  fc::variant extensions = fc::json::from_string(json.empty() ?"[]":json);

  // fill in block header here
  fc::variant_object_builder block_variant_builder; 
  block_variant_builder
  ("witness", block["name"].c_str())
  ("block_id", fix_pxx_hex(block["hash"]))
  ("previous", fix_pxx_hex(block["prev"]))
  ("timestamp", fix_pxx_time(block["created_at"]))
  ("extensions", extensions)
  ("signing_key", block["signing_key"].c_str())
  ("transactions", transaction_variants)
  ("witness_signature", fix_pxx_hex(block["witness_signature"]))
  ("transaction_merkle_root", fix_pxx_hex(block["transaction_merkle_root"]))
  ("transaction_ids", transaction_ids_variants);

  fc::variant block_variant;
  to_variant(block_variant_builder.get(), block_variant);
  return block_variant;
}

void blocks2replay(const char *context, const char* shared_memory_bin_path)
{
 for(const auto& block : blocks)
  {
    fc::variant v = block2variant(block);

    auto block_num = block["num"].as<int>();

    //std::string json = fc::json::to_pretty_string(v);
    //wlog("block_num=${block_num} header=${j}", ("block_num", block_num) ( "j", json));

    consensus_state_provider::consume_variant_block_impl(v, context, block_num, shared_memory_bin_path);
    
  }
}

void run(int from, int to, const char *context, const char *postgres_url, const char* shared_memory_bin_path) 
{
  get_data_from_postgres(from, to, postgres_url);

  initialize_iterators();
  
  blocks2replay(context, shared_memory_bin_path);
}

};


static auto volatile stop_in_consensus_state_provider_replay_impl=false;

bool consensus_state_provider_replay_impl(int from, int to, const char *context,
                                const char *postgres_url, const char* shared_memory_bin_path) 
{

  while(stop_in_consensus_state_provider_replay_impl)
  {
      int a = 0;
      (void)a;
  }

  if(from != consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path))
  {
    elog("ERROR: Cannot replay consensus state provider: Initial \"from\" block number is ${from}, but current state is expecting ${curr}",
        ("from", from)("curr", consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path)));
    return false;
  }

  Postgres2Blocks p2b;
  p2b.run(from, to, context, postgres_url, shared_memory_bin_path); 
  return true;
}

void init(hive::chain::database& db, const char* context, const char* shared_memory_bin_path)
{

  db.set_flush_interval( 10'000 );//10 000
  db.set_require_locking( false );// false 


  hive::chain::open_args db_open_args;

  db_open_args.data_dir = shared_memory_bin_path;
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

  db.open( db_open_args);

}



int initialize_context(const char* context, const char* shared_memory_bin_path)
{
  if(!consensus_state_provider::get_cache().has_context(context))
  {
    hive::chain::database* db = new hive::chain::database;
    init(*db, context, shared_memory_bin_path);
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


void consume_variant_block_impl(const fc::variant& v, const char* context, int block_num, const char* shared_memory_bin_path)
{

  static auto first_time = true;
  if(first_time)
  {
    first_time = false;
    wlog("mtlk consume_variant_block_impl first_time pid= ${pid}", ("pid", getpid()));
  }


  if(block_num != initialize_context(context, shared_memory_bin_path))
     return;



  hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
  

  

 
  std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_variant_to_full_block_ptr(v, block_num);

  

  uint64_t skip_flags = hive::chain::database::skip_block_log;
  // skip_flags |= hive::plugins::chain::database::skip_validate_invariants;
  
  //skip_flags |= hive::plugins::chain::database::skip_witness_signature ; //try not to skip it mtlk 
  // skip_flags |= hive::plugins::chain::database::skip_transaction_signatures;
  // skip_flags |= hive::plugins::chain::database::skip_transaction_dupe_check;
  //skip_flags |= hive::plugins::chain::database::skip_tapos_check; //try not to skip it mtlk 
  //skip_flags |= hive::plugins::chain::database::skip_merkle_check;//try not to skip it mtlk 
  // skip_flags |= hive::plugins::chain::database::skip_witness_schedule_check;
  //skip_flags |= hive::plugins::chain::database::skip_authority_check;//try not to skip it mtlk 
  // skip_flags |= hive::plugins::chain::database::skip_validate;



      skip_flags |= hive::chain::database::skip_witness_signature |
      hive::chain::database::skip_transaction_signatures |
      hive::chain::database::skip_transaction_dupe_check |
      hive::chain::database::skip_tapos_check |
      hive::chain::database::skip_merkle_check |
      hive::chain::database::skip_witness_schedule_check |
      hive::chain::database::skip_authority_check |
      hive::chain::database::skip_validate; /// no need to validate operations


  db.set_tx_status( hive::chain::database::TX_STATUS_BLOCK );


  db.public_apply_block(fb_ptr, skip_flags);

  db.clear_tx_status();



  db.set_revision( db.head_block_num() );
}

int consensus_state_provider_get_expected_block_num_impl(const char* context, const char* shared_memory_bin_path)
{
  return initialize_context(context, shared_memory_bin_path);
}

void consensus_state_provider_finish_impl(const char* context, const char* shared_memory_bin_path)
{
  if(consensus_state_provider::get_cache().has_context(context))
  {
      hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
      db.close();
      
      db. chainbase::database::wipe( fc::path(shared_memory_bin_path)  /  "blockchain" );
      consensus_state_provider::get_cache().remove(context);

  }
}
}
