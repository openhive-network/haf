#include "consensus_state_provider_replay.hpp"

#include "fc/variant.hpp"
#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>

#include "hive/chain/database.hpp"
#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"
#include <limits>
#include <pqxx/pqxx>

#include <hive/plugins/block_api/block_api_objects.hpp>
#include "hive/plugins/database_api/consensus_state_provider_cache.hpp"


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
  void run(int from, int to, const char* context, const char* postgres_url, const char* shared_memory_bin_path, bool allow_reevaluate)
  {
    get_data_from_postgres(from, to, postgres_url);

    initialize_iterators();

    blocks2replay(context, shared_memory_bin_path, allow_reevaluate);
  }

  void handle_exception(std::exception_ptr exception_ptr)
  {
    try
    {
      if(exception_ptr)
      {
        // do something for all exceptions
        std::rethrow_exception(exception_ptr);
      }
    }
    catch(const pqxx::broken_connection& ex)
    {
      elog("Postgres2Blocks detected connection error: ${e}.", ("e", ex.what()));
      // try_to_restore_connection(); 
    }
    catch(const pqxx::sql_error& ex)
    {
      elog("Postgres2Blocks detected SQL statement execution failure. Failing statement: `${q}'.", ("q", ex.query()));
    }
    catch(const pqxx::pqxx_exception& ex)
    {
      elog("Postgres2Blocks detected SQL execution failure: ${e}.", ("e", ex.base().what()));
    }
    catch(...)
    {
      elog("Postgres2Blocks execution failed: unknown exception.");
    }
  }

  void get_data_from_postgres(int from, int to, const char* postgres_url)
  {
    try
    {
      
      auto start = std::chrono::high_resolution_clock::now();

      PostgresDatabase db(postgres_url);
      // clang-format off
      auto blocks_query = "SELECT * FROM hive.blocks JOIN hive.accounts ON  id = producer_account_id WHERE num >= " 
                                  + std::to_string(from) 
                                  + " and num <= " 
                                  + std::to_string(to) 
                                  + " ORDER BY num ASC";
      blocks = db.execute_query(blocks_query);
      std::cout << " Blocks: " << blocks.size() << " "; 

      auto transactions_query = "SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix, expiration, trx_hash, signature FROM hive.transactions WHERE block_num >= " 
                                  + std::to_string(from) 
                                  + " and block_num <= " 
                                  + std::to_string(to) 
                                  + " ORDER BY block_num, trx_in_block ASC";
      transactions = db.execute_query(transactions_query);
      std::cout << "Transactions: " << transactions.size() << " ";

      auto operations_query = "SELECT block_num, body, trx_in_block FROM hive.operations WHERE block_num >= " 
                                  + std::to_string(from) 
                                  + " and block_num <= " 
                                  + std::to_string(to) 
                                  + " AND op_type_id <= 49 "
                                  + " ORDER BY id ASC";
    operations = db.execute_query(operations_query);
    std::cout << "Operations: " << operations.size() << std::endl;
      // clang-format on
      auto end = std::chrono::high_resolution_clock::now();            
      auto duration = std::chrono::duration_cast<std::chrono::seconds>(end - start);
      auto hours = duration.count() / 3600;
      auto minutes = (duration.count() % 3600) / 60;
      auto seconds = duration.count() % 60;
      std::cout << " postgres took: " << hours << " hours, " << minutes << " minutes, " << seconds << " seconds" << " ";

    }
    catch(...)
    {
      auto current_exception = std::current_exception();
      handle_exception(current_exception);
    }
  }

  void initialize_iterators()
  {
    current_transaction = transactions.begin();
    current_operation = operations.begin();
  }

  void blocks2replay(const char *context, const char* shared_memory_bin_path, bool allow_reevaluate)
  {
  for(const auto& block : blocks)
    {
      fc::variant v = block2variant(block);

      auto block_num = block["num"].as<int>();

      //std::string json = fc::json::to_pretty_string(v);
      //wlog("block_num=${block_num} header=${j}", ("block_num", block_num) ( "j", json));

      consensus_state_provider::apply_variant_block(v, context, block_num, shared_memory_bin_path, allow_reevaluate);
      
    }
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


  void transactions2variants(int block_num, std::vector<fc::variant>& transaction_id_variants, std::vector<fc::variant>& trancaction_variants)
  {
    auto is_current_transaction = [](const pqxx::result::const_iterator& current_transaction, const int block_num) -> bool
    {
        return current_transaction["block_num"].as<int>() == block_num;
    };

    auto build_signatures = [](const pqxx::result::const_iterator& transaction)  -> std::vector<std::string>
    {
      std::vector<std::string> signatures;
      if (strlen(transaction["signature"].c_str())) 
      {
        signatures.push_back(fix_pxx_hex(transaction["signature"]));
      }
      return signatures;
    };

    auto build_transaction_ids = [](const pqxx::result::const_iterator& transaction, std::vector<fc::variant>& transaction_id_variants)
    {
      transaction_id_variants.push_back(fix_pxx_hex(transaction["trx_hash"]));
    };

    auto rewind_operations_iterator_to_current_block = [this](int block_num)
    {
      while (current_operation_block_num() < block_num && current_operation != operations.end())
      {
        ++current_operation;
      }
    };

    auto build_transaction_variant = [](const pqxx::result::const_iterator& transaction, const std::vector<std::string>& signatures, const std::vector<fc::variant>& operations_variants) -> fc::variant
    {
      fc::variant_object_builder transaction_variant_builder;
      transaction_variant_builder
        ("ref_block_num", transaction["ref_block_num"].as<int>())
        ("ref_block_prefix", transaction["ref_block_prefix"].as<int64_t>())
        ("expiration", fix_pxx_time(transaction["expiration"]))
        ("signatures", signatures)
        ("operations", operations_variants);

      return transaction_variant_builder.get();
    };  
    
    // End of local functions definitions
    // ===================================

    // Main body of the function
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


  std::vector<fc::variant> operations2variants(int block_num, int trx_in_block)
  {
    auto is_current_operation = [this](int block_num, int trx_in_block) 
    {
      return block_num == current_operation_block_num() && trx_in_block == current_operation_trx_num();
    };

    auto operation_matches_block_transaction = [](const pqxx::const_result_iterator& operation, int block_num, int trx_in_block) 
    {
        return operation["block_num"].as<int>() == block_num && operation["trx_in_block"].as<int>() == trx_in_block;
    };

    auto add_operation_variant = [](const pqxx::const_result_iterator& operation, std::vector<fc::variant>& operations_variants)
    {
        const auto& body_in_json = operation["body"].c_str();
        const auto& operation_variant = fc::json::from_string(body_in_json);
        operations_variants.emplace_back(operation_variant);
    };

    // End of local functions definitions
    // ===================================

    // Main body of the function
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


}; //struct Postgres2Blocks


bool consensus_state_provider_replay_impl(int from, int to, const char *context,
                                const char *postgres_url, const char* shared_memory_bin_path
                                ,
                                bool allow_reevaluate
                                 ) 
{

  if(from != consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path))
  {
    if(allow_reevaluate)
    {
      wlog("WARNING: Cannot replay consensus state provider properly, but reevaluating anyway: Initial \"from\" block number is ${from}, but current state is expecting ${curr}",
          ("from", from)("curr", consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path)));
    }
    else
    {
      elog("ERROR: Cannot replay consensus state provider: Initial \"from\" block number is ${from}, but current state is expecting ${curr}",
          ("from", from)("curr", consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path)));
      return false;
    }
  }

  Postgres2Blocks p2b;
  p2b.run(from, to, context, postgres_url, shared_memory_bin_path, allow_reevaluate); 
  return true;
}







int initialize_context(const char* context, const char* shared_memory_bin_path)
{


  auto create_and_init_database = [](const char* context, const char* shared_memory_bin_path) -> hive::chain::database*
  {

    auto initialize_chain_db = [](hive::chain::database& db, const char* context, const char* shared_memory_bin_path)
    {

      auto set_open_args_data_dir = [](hive::chain::open_args& db_open_args, const char* shared_memory_bin_path)
      {
        db_open_args.data_dir = shared_memory_bin_path;
        db_open_args.shared_mem_dir = db_open_args.data_dir / "blockchain";
      };

      auto set_open_args_supply = [](hive::chain::open_args& db_open_args)
      {
        db_open_args.initial_supply = HIVE_INIT_SUPPLY;
        db_open_args.hbd_initial_supply = HIVE_HBD_INIT_SUPPLY;
      };

      auto set_open_args_other_parameters = [](hive::chain::open_args& db_open_args)
      {
        db_open_args.shared_file_size = 25769803776;
        db_open_args.shared_file_full_threshold = 0;
        db_open_args.shared_file_scale_rate = 0;
        db_open_args.chainbase_flags = 0;
        db_open_args.do_validate_invariants = false;
        db_open_args.stop_replay_at = 0;
        db_open_args.exit_after_replay = false;
        db_open_args.validate_during_replay = false;
        db_open_args.benchmark_is_enabled = false;
        db_open_args.replay_in_memory = false;
        db_open_args.enable_block_log_compression = true;
        db_open_args.block_log_compression_level = 15;
        db_open_args.postgres_not_block_log = true;
        db_open_args.force_replay = false;
      };

      // End of local functions definitions
      // ===================================

      // Main body of the function
      db.set_flush_interval(10'000);
      db.set_require_locking(false);

      hive::chain::open_args db_open_args;

      set_open_args_data_dir(db_open_args, shared_memory_bin_path);
      set_open_args_supply(db_open_args);
      set_open_args_other_parameters(db_open_args);

      db.open(db_open_args);
    };


    hive::chain::database* db = new hive::chain::database;
    initialize_chain_db(*db, context, shared_memory_bin_path);
    consensus_state_provider::get_cache().add(context, db);
    return db;
  };

  hive::chain::database* db;

  if (!consensus_state_provider::get_cache().has_context(context))
  {
    db = create_and_init_database(context, shared_memory_bin_path);
  }
  else
  {
    db = &consensus_state_provider::get_cache().get_db(context);
  }

  return db->head_block_num() + 1;
}




struct fix_hf_version_visitor
{
  fix_hf_version_visitor(int a_proper_version):proper_version(a_proper_version){}

  typedef void result_type;

  void operator()(  hive::void_t& obj ) const
  {
    //Nothing to do.
  }

  void operator()(  hive::protocol::version& reported_version ) const
  {
    //Nothing to do.
  }

  void operator()(  hive::protocol::hardfork_version_vote& hfv ) const
  {
    auto& ver = hfv.hf_version;
    static_cast<hive::protocol::version&>(ver) = hive::protocol::version( 0, 0, proper_version);
  }

#ifdef IS_TEST_NET
  void operator()( const hive::chain::required_automated_actions& req_actions ) const
  {
    //Nothing to do.
  }

  void operator()( const hive::chain::optional_automated_actions& opt_actions ) const
  {
    //Nothing to do.
  }
#endif

private:
  int proper_version;
};

void fix_hf_version(hive::plugins::block_api::api_signed_block_object& sb, int proper_hf_version, int block_num)
{
    fix_hf_version_visitor visitor(proper_hf_version);

    for (auto& extension : sb.extensions)
    {
        extension.visit(visitor);
    }
    ilog("Fixing minor hardfork version in extension in block ${block_num}", ("block_num", block_num));
}


std::shared_ptr<hive::chain::full_block_type> from_variant_to_full_block_ptr(const fc::variant& v, int block_num )
{
  hive::plugins::block_api::api_signed_block_object sb;

  fc::from_variant( v, sb );

  switch(block_num)
  {
    case 2726331: fix_hf_version(sb, 489, block_num); break;
    case 2730591: fix_hf_version(sb, 118, block_num); break;
    case 2733423: fix_hf_version(sb, 119, block_num); break;
    case 2768535: fix_hf_version(sb, 116, block_num); break;
    case 2781318: fix_hf_version(sb, 116, block_num); break;
    case 2786287: fix_hf_version(sb, 119, block_num); break;
  }

  return hive::chain::full_block_type::create_from_signed_block(sb);
}


void apply_variant_block(const fc::variant& v, const char* context, int block_num, const char* shared_memory_bin_path, bool allow_reevaluate)
{
  auto get_skip_flags = [] () -> uint64_t
  {
    return hive::chain::database::skip_block_log |
          hive::chain::database::skip_witness_signature |
          hive::chain::database::skip_transaction_signatures |
          hive::chain::database::skip_transaction_dupe_check |
          hive::chain::database::skip_tapos_check |
          hive::chain::database::skip_merkle_check |
          hive::chain::database::skip_witness_schedule_check |
          hive::chain::database::skip_authority_check |
          hive::chain::database::skip_validate;
  };

  auto apply_full_block = [](hive::chain::database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr, uint64_t skip_flags)
  {
    db.set_tx_status(hive::chain::database::TX_STATUS_BLOCK);
    db.public_apply_block(fb_ptr, skip_flags);
    db.clear_tx_status();
    db.set_revision(db.head_block_num());
  };

  // End of local functions definitions
  // ===================================

  // Main body of the function
  if(!allow_reevaluate)
    if (block_num != initialize_context(context, shared_memory_bin_path))
      return;

  hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
  std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_variant_to_full_block_ptr(v, block_num);
  uint64_t skip_flags = get_skip_flags();

  apply_full_block(db, fb_ptr, skip_flags);
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
