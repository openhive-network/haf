#include "consensus_state_provider_replay.hpp"

#include "fc/variant.hpp"
#include <chrono>
#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>

#include "hive/chain/database.hpp"
#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"
#include <limits>
#include <iomanip>
#include <pqxx/pqxx>

#include <hive/plugins/block_api/block_api_objects.hpp>
#include "hive/plugins/database_api/consensus_state_provider_cache.hpp"

#include <hive/protocol/hive_operations.hpp>

namespace consensus_state_provider
{




struct Postgres2Blocks
{
  void run(int from, int to, const char* context, const char* postgres_url, const char* shared_memory_bin_path, bool allow_reevaluate);
  void handle_exception(std::exception_ptr exception_ptr);
  void get_data_from_postgres(int from, int to, const char* postgres_url);
  void initialize_iterators();
  void blocks2replay(const char *context, const char* shared_memory_bin_path, bool allow_reevaluate);
  void apply_variant_block(const pqxx::row& block, const char* context, const char* shared_memory_bin_path, bool allow_reevaluate);
  fc::variant block2variant(const pqxx::row& block);
  
  void transactions2variants(int block_num, std::vector<fc::variant>& transaction_id_variants, std::vector<fc::variant>& trancaction_variants);

  struct variant_and_binary_type
  {
      fc::variant variant;
      pqxx::binarystring binary_str;
  };

  std::vector<variant_and_binary_type> operations2variants(int block_num, int trx_in_block);
  int current_transaction_block_num();
  int current_operation_block_num() const;
  int current_operation_trx_num() const;

  pqxx::result blocks;
  pqxx::result transactions;
  pqxx::result operations;
  pqxx::result::const_iterator current_transaction;
  pqxx::result::const_iterator current_operation;
  std::chrono::nanoseconds transformations_duration;
};

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


//struct pre_operation_visitor
using namespace hive::protocol;

struct conensus_op_visitor_type
{

  conensus_op_visitor_type( ){}

  typedef void result_type;

  template< typename T >
  void operator()( const T& )const 
  {
    int a= 0;
    a = 1; 
    (void)a; 
  }

  void operator()( const account_create_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const account_create_with_delegation_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const account_update_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const account_update2_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const create_claimed_account_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const recover_account_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const pow_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const pow2_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const hardfork_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }



  void operator()( const transfer_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }


  void operator()( const transfer_to_vesting_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }


  void operator()( const account_witness_vote_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const comment_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const vote_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const withdraw_vesting_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }

  void operator()( const account_witness_proxy_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }


  void operator()( const feed_publish_operation & op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }


  void operator()( const witness_update_operation& op )const
  {
    int a= 0;
    a = 1;
    (void)a;
  }


private:
};


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


void get_into_op(const pqxx::binarystring& bs)
{


      //_operation* operation_body = PG_GETARG_HIVE_OPERATION_PP( 0 );


        //VARDATA_ANY( operation_body ), VARSIZE_ANY_EXHDR( operation_body ));

          using hive::protocol::operation;

          const char* raw_data = reinterpret_cast<const char*>(bs.data());
          uint32_t data_length = bs.size();

        operation op = fc::raw::unpack_from_char_array< operation >( raw_data, data_length );

        conensus_op_visitor_type conensus_op_visitor;
        op.visit(conensus_op_visitor);

        //note.op.visit( post_operation_visitor( *this ) );


}





  void Postgres2Blocks::run(int from, int to, const char* context, const char* postgres_url, const char* shared_memory_bin_path, bool allow_reevaluate)
  {
    transformations_duration = std::chrono::nanoseconds();
    get_data_from_postgres(from, to, postgres_url);

    initialize_iterators();

    blocks2replay(context, shared_memory_bin_path, allow_reevaluate);

    
    print_duration("Trans", transformations_duration);
  }

  void Postgres2Blocks::handle_exception(std::exception_ptr exception_ptr)
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

  void Postgres2Blocks::get_data_from_postgres(int from, int to, const char* postgres_url)
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
      std::cout << "Blocks:" << blocks.size() << " "; 

      auto transactions_query = "SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix, expiration, trx_hash, signature FROM hive.transactions WHERE block_num >= " 
                                  + std::to_string(from) 
                                  + " and block_num <= " 
                                  + std::to_string(to) 
                                  + " ORDER BY block_num, trx_in_block ASC";
      transactions = db.execute_query(transactions_query);
      std::cout << "Transactions:" << transactions.size() << " ";

      auto operations_query = "SELECT block_num, body, body::bytea as bin_body, trx_in_block FROM hive.operations WHERE block_num >= " 
                                  + std::to_string(from) 
                                  + " and block_num <= " 
                                  + std::to_string(to) 
                                  + " AND op_type_id <= 49 " //trx_in_block < 0 -> virtual operation
                                  + " ORDER BY id ASC";
    operations = db.execute_query(operations_query);
    std::cout << "Operations:" << operations.size() << " ";
      // clang-format on
      auto end = std::chrono::high_resolution_clock::now();            
      auto duration = std::chrono::duration_cast<std::chrono::seconds>(end - start);
      print_duration("Postgres", duration);

    }
    catch(...)
    {
      auto current_exception = std::current_exception();
      handle_exception(current_exception);
    }
  }

  void Postgres2Blocks::initialize_iterators()
  {
    current_transaction = transactions.begin();
    current_operation = operations.begin();
  }

  void Postgres2Blocks::blocks2replay(const char *context, const char* shared_memory_bin_path, bool allow_reevaluate)
  {
  for(const auto& block : blocks)
    {



      apply_variant_block(block, context, shared_memory_bin_path, allow_reevaluate);
      
    }
  }

  void Postgres2Blocks::apply_variant_block(const pqxx::row& block, const char* context, const char* shared_memory_bin_path, bool allow_reevaluate)
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
    
    auto start = std::chrono::high_resolution_clock::now();

    fc::variant v = block2variant(block);
    auto block_num = block["num"].as<int>();

    //std::string json = fc::json::to_pretty_string(v);
    //wlog("block_num=${block_num} header=${j}", ("block_num", block_num) ( "j", json));

    if(!allow_reevaluate)
      if (block_num != initialize_context(context, shared_memory_bin_path))
        return;

    hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
    std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_variant_to_full_block_ptr(v, block_num);

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::nanoseconds duration = end - start;    
    transformations_duration += duration;

    uint64_t skip_flags = get_skip_flags();

    apply_full_block(db, fb_ptr, skip_flags);
  }


  fc::variant Postgres2Blocks::block2variant(const pqxx::row& block)
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



  void Postgres2Blocks::transactions2variants(int block_num, std::vector<fc::variant>& transaction_id_variants, std::vector<fc::variant>& trancaction_variants)
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

  //  https://github.com/jtv/libpqxx/blob/3d97c80bcde96fb70a21c1ae1cf92ad934818210/include/pqxx/field.hxx
  //   Do not use this for BYTEA values, or other binary values.  To read those,
  //   convert the value to your desired type using `to()` or `as()`.  For
  //   example: `f.as<std::basic_string<std::byte>>()`.
  //  
  // [[nodiscard]] PQXX_PURE char const *c_str() const &;


      pqxx::binarystring blob(transaction["trx_hash"]);
      auto size = blob.size();
      auto data = blob.data();

      (void) size;
      (void) data;

      transaction_id_variants.push_back(fix_pxx_hex(transaction["trx_hash"]));
    };

    auto rewind_operations_iterator_to_current_block = [this](int block_num)
    {
      while (current_operation_block_num() < block_num && current_operation != operations.end())
      {
        ++current_operation;
      }
    };

    auto build_transaction_variant = [](const pqxx::result::const_iterator& transaction, const std::vector<std::string>& signatures, const std::vector<variant_and_binary_type>& varbin_operations) -> fc::variant
    {
      std::vector<fc::variant> only_variants;
      only_variants.reserve(varbin_operations.size());
      std::transform(
          varbin_operations.begin(), varbin_operations.end(),
          std::back_inserter(only_variants),
          [](const variant_and_binary_type& vb) { return vb.variant; }
      );

      fc::variant_object_builder transaction_variant_builder;
      transaction_variant_builder
        ("ref_block_num", transaction["ref_block_num"].as<int>())
        ("ref_block_prefix", transaction["ref_block_prefix"].as<int64_t>())
        ("expiration", fix_pxx_time(transaction["expiration"]))
        ("signatures", signatures)
        ("operations", only_variants);

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

      std::vector<variant_and_binary_type> varbin_operations = operations2variants(block_num, trx_in_block);

      fc::variant transaction_variant = build_transaction_variant(current_transaction, signatures, varbin_operations);

      trancaction_variants.emplace_back(transaction_variant);
    }
  }


  std::vector<Postgres2Blocks::variant_and_binary_type> Postgres2Blocks::operations2variants(int block_num, int trx_in_block)
  {
    auto is_current_operation = [this](int block_num, int trx_in_block) 
    {
      return block_num == current_operation_block_num() && trx_in_block == current_operation_trx_num();
    };

    auto operation_matches_block_transaction = [](const pqxx::const_result_iterator& operation, int block_num, int trx_in_block) 
    {
        return operation["block_num"].as<int>() == block_num && operation["trx_in_block"].as<int>() == trx_in_block;
    };

    auto add_operation_variant = [](const pqxx::const_result_iterator& operation, std::vector<variant_and_binary_type>& varbin_operations)
    {

        pqxx::binarystring json(operation["body"]);
        pqxx::binarystring bs(operation["bin_body"]);

        //std::cout << "Json size: " << json.size() << " Json data: " << json.data() << std::endl;
        //std::cout << "Blob size: " << bs.size() << " Blob data: " << bs.data() << std::endl;

        
        std::cout.copyfmt(std::stringstream()); //reset stream state

        // auto data = bs.data();
        // size_t size = bs.size();



        // std::cout << "Binary data: ";
        // for (size_t i = 0; i < size; ++i) {
        //     std::cout << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>((unsigned char)data[i]);
        // }
        // std::cout << std::dec << "\n";        

        const auto& body_in_json = operation["body"].c_str();




        get_into_op(bs);

        // //fc::blob val;
        // //val.data.assign(bs.data(), bs.data() + bs.size());

        // //haf_blob_operation hbo(val);

        
        // hive::protocol::custom_binary_operation cbo;
        // cbo.data.assign(bs.data(), bs.data() + bs.size());

        // fc::operation op (cbo);

        // fc::string  s =   fc::json::to_string(op);
        // std::cout << "Cbo size: " << s.size() << " Cbo data: " << s << std::endl;
        // // const auto& operation_variant = fc::json::from_string(s);

        // fc::variant operation_variant2;
        // to_variant(op, operation_variant2);
        

        variant_and_binary_type vb
        {
          .variant = fc::json::from_string(body_in_json),
          .binary_str = bs
        };

        varbin_operations.emplace_back(vb);
        //varbin_operations.emplace_back(operation_variant2);
    };

    // End of local functions definitions
    // ===================================

    // Main body of the function
    std::vector<variant_and_binary_type> varbin_operations; 
    if(is_current_operation(block_num, trx_in_block))
    {
      for(; current_operation != operations.end() && operation_matches_block_transaction(current_operation, block_num, trx_in_block); ++current_operation)
      {
        add_operation_variant(current_operation, varbin_operations);
      }
    }
    return varbin_operations;
  }

  //iterators for traversing the values above
  int Postgres2Blocks::current_transaction_block_num() 
  { 
    if(transactions.empty())
      return -1;
    if(transactions.end() == current_transaction)
      return std::numeric_limits<int>::max();
    return current_transaction["block_num"].as<int>(); 
    }


  int Postgres2Blocks::current_operation_block_num() const 
  { 
    if(operations.empty())
      return -1;
    if(operations.end() == current_operation)
      return std::numeric_limits<int>::max();
    return current_operation["block_num"].as<int>(); 
  }

  int Postgres2Blocks::current_operation_trx_num() const 
  { 
    if(operations.empty())
      return -1;
    if(operations.end() == current_operation)
      return std::numeric_limits<int>::max();
    return current_operation["trx_in_block"].as<int>(); 
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

void print_duration(const std::string& message, const std::chrono::nanoseconds& duration) 
{
    auto minutes = std::chrono::duration_cast<std::chrono::minutes>(duration);
    auto seconds = std::chrono::duration_cast<std::chrono::seconds>(duration % std::chrono::minutes(1));

    std::cout << message << ":" << minutes.count() << "'" << seconds.count() << "\" ";
}

void print_flags(std::ios_base::fmtflags flags) 
{
    std::cout << "Format flags: ";

    if (flags & std::ios_base::boolalpha) std::cout << "boolalpha ";
    if (flags & std::ios_base::dec) std::cout << "dec ";
    if (flags & std::ios_base::fixed) std::cout << "fixed ";
    if (flags & std::ios_base::hex) std::cout << "hex ";
    if (flags & std::ios_base::internal) std::cout << "internal ";
    if (flags & std::ios_base::left) std::cout << "left ";
    if (flags & std::ios_base::oct) std::cout << "oct ";
    if (flags & std::ios_base::right) std::cout << "right ";
    if (flags & std::ios_base::scientific) std::cout << "scientific ";
    if (flags & std::ios_base::showbase) std::cout << "showbase ";
    if (flags & std::ios_base::showpoint) std::cout << "showpoint ";
    if (flags & std::ios_base::showpos) std::cout << "showpos ";
    if (flags & std::ios_base::skipws) std::cout << "skipws ";
    if (flags & std::ios_base::unitbuf) std::cout << "unitbuf ";
    if (flags & std::ios_base::uppercase) std::cout << "uppercase ";
    if (flags & std::ios_base::adjustfield) std::cout << "adjustfield ";
    if (flags & std::ios_base::basefield) std::cout << "basefield ";
    if (flags & std::ios_base::floatfield) std::cout << "floatfield ";

    std::cout << std::endl;
}




void reset_stream(std::ostream& os) 
{

   //std::stringstream dummy;
   os.copyfmt(std::stringstream());
   return;

  //  std::stringstream dummy;
  //  os.flags(dummy.flags());  // reset to default flags
  //  os.fill(dummy.fill());  // reset to default fill character
  //  os.precision(dummy.precision());  // reset to default precision

  //  return;

  //   // Clear all error flags
  //   os.clear();

  //   // Reset to the default formatting state
  //   os.unsetf(std::ios_base::adjustfield);  // Left-justified
  //   os.unsetf(std::ios_base::basefield);  // Decimal numbers
  //   os.unsetf(std::ios_base::floatfield);  // Not fixed nor scientific

  //   // Reset other settings
  //   os.precision(6);  // Default precision for floating-point output
  //   os.fill(' ');  // Default fill character
  //   os.unsetf(std::ios_base::boolalpha);  // bool values are output as 1 and 0
  //   os.unsetf(std::ios_base::showbase);  // The base prefix is not output
  //   os.unsetf(std::ios_base::showpoint);  // The decimal point and trailing zeros are output only if necessary
  //   os.unsetf(std::ios_base::showpos);  // A plus sign is not output for positive numbers
  //   os.unsetf(std::ios_base::skipws);  // White space is not skipped on input
  //   os.unsetf(std::ios_base::uppercase);  // Lowercase letters are used for the base prefix and exponent of floating-point values
}