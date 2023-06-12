#include "consensus_state_provider_replay.hpp"

#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>
#include <hive/plugins/block_api/block_api_objects.hpp>
#include <hive/protocol/hive_operations.hpp>
#include <iomanip>
#include <limits>
#include <pqxx/pqxx>

#include "fc/variant.hpp"
#include "hive/chain/database.hpp"
#include "hive/plugins/database_api/consensus_state_provider_cache.hpp"
#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"

#include "pqxx_op_iterator.hpp"
#include "time_probe.hpp" 

namespace consensus_state_provider
{

void get_into_op(const pqxx::binarystring& bs);

// value coming from pxx is without 'T' in the middle to be accepted in variant
std::string fix_pxx_time(const pqxx::field& t);

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h);

class postgres_block_log
{
public:
  void run(int from, int to, const char* context, const char* postgres_url, const char* shared_memory_bin_path);
private:
  void measure_before_run();
  void measure_after_run();
  void handle_exception(std::exception_ptr exception_ptr);
  void get_postgres_data(int from, int to, const char* postgres_url);
  void initialize_iterators();
  void replay_blocks(const char* context, const char* shared_memory_bin_path);
  void replay_block(const pqxx::row& block, const char* context, const char* shared_memory_bin_path);
  static uint64_t get_skip_flags();
  void apply_full_block(hive::chain::database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr, uint64_t skip_flags);
  fc::variant block_to_variant_with_transactions(const pqxx::row& block);
  fc::variant block_to_variant_without_transactions(const pqxx::row& block);
  fc::variant build_block_variant(const pqxx::row& block,
                                  const std::vector<fc::variant>& transaction_ids_variants,
                                  const std::vector<fc::variant>& transaction_variants);
  void apply_non_transactional_operation_block(
      hive::chain::database& db,
      pqxx::result::const_iterator& cur_op,
      const pqxx::result::const_iterator& end_it,
      int block_num,
      const std::shared_ptr<hive::chain::full_block_type>& full_block);
  void measure_before_apply_non_tansactional_operation_block();
  void measure_after_apply_non_tansactional_operation_block();  
  int get_current_block_num(pqxx::result::const_iterator& current_operation);
  void rewind_to_block_num(int current_block_num,
                           pqxx::result::const_iterator& current_operation,
                           int block_num,
                           const pqxx::result::const_iterator& end_it);
  void transactions2variants(int block_num,
                             std::vector<fc::variant>& transaction_id_variants,
                             std::vector<fc::variant>& transaction_variants);
  static bool is_current_transaction(const pqxx::result::const_iterator& current_transaction,
                                     const int block_num);
  static std::vector<std::string> build_signatures(const pqxx::result::const_iterator& transaction);
  static void build_transaction_ids(const pqxx::result::const_iterator& transaction, std::vector<fc::variant>& transaction_id_variants);
  void rewind_operations_iterator_to_current_block(int block_num);
  static fc::variant build_transaction_variant(const pqxx::result::const_iterator& transaction, const std::vector<std::string>& signatures,
                                               const std::vector<fc::variant>& operation_variants);

  std::vector<fc::variant> operations2variants(int block_num, int trx_in_block);
  bool is_current_operation(int block_num, int trx_in_block) const;
  static bool operation_matches_block_transaction(const pqxx::const_result_iterator& operation, int block_num, int trx_in_block);
  void add_operation_variant(const pqxx::const_result_iterator& operation, std::vector<fc::variant>& operation_variants);

  int current_transaction_block_num();
  int current_operation_block_num() const;
  int current_operation_trx_num() const;

  pqxx::result blocks;
  pqxx::result transactions;
  pqxx::result operations;
  pqxx::result::const_iterator current_transaction;
  pqxx::result::const_iterator current_operation;
  std::chrono::nanoseconds transformations_duration;
  time_probe transformations_time_probe;
  time_probe apply_full_block_time_probe;
  time_probe non_transactional_apply_op_block_time_probe;

  class postgres_database_helper
  {
  public:
    explicit postgres_database_helper(const char* url) : connection(url) {}

    pqxx::result execute_query(const std::string& query)
    {
      pqxx::work txn(connection);
      pqxx::result query_result = txn.exec(query);
      txn.commit();
      return query_result;
    }

  private:
    pqxx::connection connection;
  }; 
  const int BLOCK_NUM_EMPTY = -1;
  const int BLOCK_NUM_MAX = std::numeric_limits<int>::max();
};



bool consensus_state_provider_replay_impl(int from, int to, const char* context, const char* postgres_url,
                                          const char* shared_memory_bin_path)
{
  if(from != consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path))
  {
      elog(
          "ERROR: Cannot replay consensus state provider: Initial \"from\" block number is ${from}, but current state is expecting ${curr}",
          ("from", from)("curr", consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path)));
      return false;
  }

  postgres_block_log().run(from, to, context, postgres_url, shared_memory_bin_path);
  return true;
}

void postgres_block_log::run(int from,
                             int to,
                             const char* context,
                             const char* postgres_url,
                             const char* shared_memory_bin_path)
{
  measure_before_run();

  try
  {
    get_postgres_data(from, to, postgres_url);
    initialize_iterators();
    replay_blocks(context, shared_memory_bin_path);
  }
  catch(...)
  {
    auto current_exception = std::current_exception();
    handle_exception(current_exception);
  }

  measure_after_run();
}

void postgres_block_log::measure_before_run()
{
  transformations_time_probe.reset();
  apply_full_block_time_probe.reset();
  non_transactional_apply_op_block_time_probe.reset();
}

void postgres_block_log::measure_after_run()
{
  transformations_time_probe.print_duration("Transformations");
  apply_full_block_time_probe.print_duration("Transactional_apply_block");
  non_transactional_apply_op_block_time_probe.print_duration("Non-transactional_apply_block");
}

void postgres_block_log::handle_exception(std::exception_ptr exception_ptr)
{
  try
  {
    if(exception_ptr)
    {
      std::rethrow_exception(exception_ptr);
    }
  }
  catch(const pqxx::broken_connection& ex)
  {
    elog("postgres_block_log detected connection error: ${e}.", ("e", ex.what()));
  }
  catch(const pqxx::sql_error& ex)
  {
    elog("postgres_block_log detected SQL statement execution failure. Failing statement: `${q}'.", ("q", ex.query()));
  }
  catch(const pqxx::pqxx_exception& ex)
  {
    elog("postgres_block_log detected SQL execution failure: ${e}.", ("e", ex.base().what()));
  }
  catch(...)
  {
    elog("postgres_block_log execution failed: unknown exception.");
  }
}

void postgres_block_log::get_postgres_data(int from, int to, const char* postgres_url)
{
  time_probe get_data_from_postgres_time_probe; get_data_from_postgres_time_probe.start();

  postgres_database_helper db{postgres_url};
  
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
  get_data_from_postgres_time_probe.stop(); get_data_from_postgres_time_probe.print_duration("Postgres");
}


void postgres_block_log::initialize_iterators()
{
  current_transaction = transactions.begin();
  current_operation = operations.begin();
}

void postgres_block_log::replay_blocks(const char* context, const char* shared_memory_bin_path)
{
  for(const auto& block : blocks)
  {
    replay_block(block, context, shared_memory_bin_path);
  }
}

void postgres_block_log::replay_block(const pqxx::row& block, const char* context, const char* shared_memory_bin_path)
{
  transformations_time_probe.start();

  auto block_num = block["num"].as<int>();

  if(block_num != initialize_context(context, shared_memory_bin_path)) 
    return;

  hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);

   bool classic_way = (block_num <= 1092);
   //bool classic_way = true;
   
  if(classic_way)
  {

    fc::variant v = block_to_variant_with_transactions(block);

    // std::string json = fc::json::to_pretty_string(v);
    // wlog("block_num=${block_num} header=${j}", ("block_num", block_num) ( "j", json));

    std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_variant_to_full_block_ptr(v, block_num);
    transformations_time_probe.stop();

    apply_full_block(db, fb_ptr, get_skip_flags());
    
  }
  else
  {
    fc::variant v = block_to_variant_without_transactions(block);
    std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_variant_to_full_block_ptr(v, block_num);
    transformations_time_probe.stop();

    apply_non_transactional_operation_block(db, current_operation, operations.end(), block_num, fb_ptr);
  }
}

void postgres_block_log::apply_full_block(hive::chain::database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr,
                                       uint64_t skip_flags)
{
  apply_full_block_time_probe.start();

  db.set_tx_status(hive::chain::database::TX_STATUS_BLOCK);
  db.public_apply_block(fb_ptr, skip_flags);
  db.clear_tx_status();
  db.set_revision(db.head_block_num());

  apply_full_block_time_probe.stop();
}


void postgres_block_log::apply_non_transactional_operation_block(
    hive::chain::database& db,
    pqxx::result::const_iterator& cur_op,
    const pqxx::result::const_iterator& end_it,
    int block_num,
    const std::shared_ptr<hive::chain::full_block_type>& full_block)
{
  measure_before_apply_non_tansactional_operation_block();

  db.set_tx_status(hive::chain::database::TX_STATUS_BLOCK);

  int current_block_num = get_current_block_num(cur_op);

  rewind_to_block_num(current_block_num, cur_op, block_num, end_it);

  hive::chain::op_iterator_ptr op_it(new pqxx_op_iterator(cur_op,
                    end_it,
                    block_num));
    
  db.non_transactional_apply_block(full_block, std::move(op_it), get_skip_flags());

  db.clear_tx_status();
  db.set_revision(db.head_block_num());


  measure_after_apply_non_tansactional_operation_block();
}

void postgres_block_log::measure_before_apply_non_tansactional_operation_block()
{
  // Start time probe here
  non_transactional_apply_op_block_time_probe.start();
}

int postgres_block_log::get_current_block_num(pqxx::result::const_iterator& current_operation)
{
  // Return the current block number
  if(operations.empty())
    return BLOCK_NUM_EMPTY;
  if(operations.end() == current_operation)
    return BLOCK_NUM_MAX;
  return current_operation["block_num"].as<int>();
}

void postgres_block_log::rewind_to_block_num(int current_block_num,
                                             pqxx::result::const_iterator& current_operation,
                                             int block_num,
                                             const pqxx::result::const_iterator& end_it)
{
  while(current_block_num < block_num && current_operation != end_it)
  {
    ++current_operation;
  }
}

void postgres_block_log::measure_after_apply_non_tansactional_operation_block()
{
  non_transactional_apply_op_block_time_probe.stop();
}

fc::variant postgres_block_log::block_to_variant_with_transactions(const pqxx::row& block)
{
  auto block_num = block["num"].as<int>();

  std::vector<fc::variant> transaction_ids_variants;
  std::vector<fc::variant> transaction_variants;
  
  if(block_num == current_transaction_block_num()) 
    transactions2variants(block_num, transaction_ids_variants, transaction_variants);

  return build_block_variant(block, transaction_ids_variants, transaction_variants);
}

fc::variant postgres_block_log::block_to_variant_without_transactions(const pqxx::row& block)
{
  std::vector<fc::variant> transaction_ids_variants; // Empty as no transactions
  std::vector<fc::variant> transaction_variants;     // Empty as no transactions
  
  return build_block_variant(block, transaction_ids_variants, transaction_variants);
}

// Common function to build block variant
fc::variant postgres_block_log::build_block_variant(const pqxx::row& block,
                                                    const std::vector<fc::variant>& transaction_ids_variants,
                                                    const std::vector<fc::variant>& transaction_variants)
{
  std::string json = block["extensions"].c_str();
  fc::variant extensions = fc::json::from_string(json.empty() ? "[]" : json);

  fc::variant_object_builder block_variant_builder;

  block_variant_builder
    ("witness", block["name"].c_str())
    ("block_id", fix_pxx_hex(block["hash"]))
    ("previous", fix_pxx_hex(block["prev"]))
    ("timestamp", fix_pxx_time(block["created_at"]))
    ("extensions", extensions)
    ("signing_key", block["signing_key"].c_str())
    ("witness_signature", fix_pxx_hex(block["witness_signature"]))
    ("transaction_merkle_root", fix_pxx_hex(block["transaction_merkle_root"]))
    ("transaction_ids", transaction_ids_variants);

  if (!transaction_variants.empty())
    block_variant_builder("transactions", transaction_variants);

  fc::variant block_variant;
  to_variant(block_variant_builder.get(), block_variant);

  return block_variant;
}

void postgres_block_log::transactions2variants(int block_num, std::vector<fc::variant>& transaction_id_variants,
                                            std::vector<fc::variant>& transaction_variants)
{
  for(; current_transaction != transactions.end() && is_current_transaction(current_transaction, block_num); ++current_transaction)
  {
    auto trx_in_block = current_transaction["trx_in_block"].as<int>();

    std::vector<std::string> signatures = build_signatures(current_transaction);

    build_transaction_ids(current_transaction, transaction_id_variants);

    rewind_operations_iterator_to_current_block(block_num);

    std::vector<fc::variant> operation_variants = operations2variants(block_num, trx_in_block);

    fc::variant transaction_variant = build_transaction_variant(current_transaction, signatures, operation_variants);

    transaction_variants.emplace_back(transaction_variant);
  }
}

bool postgres_block_log::is_current_transaction(const pqxx::result::const_iterator& current_transaction, const int block_num)
{
  return current_transaction["block_num"].as<int>() == block_num;
}

std::vector<std::string> postgres_block_log::build_signatures(const pqxx::result::const_iterator& transaction)
{
  std::vector<std::string> signatures;
  if(strlen(transaction["signature"].c_str()))
  {
    signatures.push_back(fix_pxx_hex(transaction["signature"]));
  }
  return signatures;
}

void postgres_block_log::build_transaction_ids(const pqxx::result::const_iterator& transaction,
                                            std::vector<fc::variant>& transaction_id_variants)
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

  (void)size;
  (void)data;

  transaction_id_variants.push_back(fix_pxx_hex(transaction["trx_hash"]));
}

void postgres_block_log::rewind_operations_iterator_to_current_block(int block_num)
{
  while(current_operation_block_num() < block_num && current_operation != operations.end())
  {
    ++current_operation;
  }
};

fc::variant postgres_block_log::build_transaction_variant(const pqxx::result::const_iterator& transaction,
                                                       const std::vector<std::string>& signatures,
                                                       const std::vector<fc::variant>& operation_variants)
{
      // clang-format off
  fc::variant_object_builder transaction_variant_builder;
  transaction_variant_builder
    ("ref_block_num", transaction["ref_block_num"].as<int>())
    ("ref_block_prefix", transaction["ref_block_prefix"].as<int64_t>())
    ("expiration", fix_pxx_time(transaction["expiration"]))
    ("signatures", signatures)
    ("operations", operation_variants);
    // clang-format on

  return transaction_variant_builder.get();
}

std::vector<fc::variant> postgres_block_log::operations2variants(int block_num, int trx_in_block)
{
  std::vector<fc::variant> operation_variants;
  if(is_current_operation(block_num, trx_in_block))
  {
    for(; current_operation != operations.end() && operation_matches_block_transaction(current_operation, block_num, trx_in_block);
        ++current_operation)
    {
      add_operation_variant(current_operation, operation_variants);
    }
  }
  return operation_variants;
}

bool postgres_block_log::is_current_operation(int block_num, int trx_in_block) const
{
  return block_num == current_operation_block_num() && trx_in_block == current_operation_trx_num();
}

bool postgres_block_log::operation_matches_block_transaction(const pqxx::const_result_iterator& operation, int block_num, int trx_in_block) 
{
  return operation["block_num"].as<int>() == block_num && operation["trx_in_block"].as<int>() == trx_in_block;
}

void postgres_block_log::add_operation_variant(const pqxx::const_result_iterator& operation, std::vector<fc::variant>& operation_variants)
{
    pqxx::binarystring json(operation["body"]);
    //pqxx::binarystring bs(operation["bin_body"]);

    //std::cout << "Json size: " << json.size() << " Json data: " << json.data() << std::endl;
    //std::cout << "Blob size: " << bs.size() << " Blob data: " << bs.data() << std::endl;

    
    //std::cout.copyfmt(std::stringstream()); //reset stream state

    // auto data = bs.data();
    // size_t size = bs.size();



    // std::cout << "Binary data: ";
    // for (size_t i = 0; i < size; ++i) {
    //     std::cout << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>((unsigned char)data[i]);
    // }
    // std::cout << std::dec << "\n";        

    const auto& body_in_json = operation["body"].c_str();




    //get_into_op(bs);

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
    

    //fc::variant vb = fc::json::from_string(body_in_json);

    operation_variants.emplace_back(fc::json::from_string(body_in_json));
    //operation_variants.emplace_back(operation_variant2);
}



  //iterators for traversing the values above
  int postgres_block_log::current_transaction_block_num()
{
  if(transactions.empty()) return BLOCK_NUM_EMPTY;
  if(transactions.end() == current_transaction) return BLOCK_NUM_MAX;
  return current_transaction["block_num"].as<int>();
}

int postgres_block_log::current_operation_block_num() const
{
  if(operations.empty()) return BLOCK_NUM_EMPTY;
  if(operations.end() == current_operation) return BLOCK_NUM_MAX;
  return current_operation["block_num"].as<int>();
}

int postgres_block_log::current_operation_trx_num() const
{
  if(operations.empty()) return BLOCK_NUM_EMPTY;
  if(operations.end() == current_operation) return BLOCK_NUM_MAX;
  return current_operation["trx_in_block"].as<int>();
}


uint64_t postgres_block_log::get_skip_flags()
{
  // clang-format off
  return hive::chain::database::skip_block_log |
        hive::chain::database::skip_witness_signature |
        hive::chain::database::skip_transaction_signatures |
        hive::chain::database::skip_transaction_dupe_check |
        hive::chain::database::skip_tapos_check |
        hive::chain::database::skip_merkle_check |
        hive::chain::database::skip_witness_schedule_check |
        hive::chain::database::skip_authority_check |
        hive::chain::database::skip_validate;
  // clang-format on
};

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

  if(!consensus_state_provider::get_cache().has_context(context))
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
  explicit fix_hf_version_visitor(int a_proper_version) : proper_version(a_proper_version) {}

  typedef void result_type;

  void operator()(hive::void_t& obj) const
  {
    // Nothing to do.
  }

  void operator()(hive::protocol::version& reported_version) const
  {
    // Nothing to do.
  }

  void operator()(hive::protocol::hardfork_version_vote& hfv) const
  {
    auto& ver = hfv.hf_version;
    static_cast<hive::protocol::version&>(ver) = hive::protocol::version(0, 0, proper_version);
  }

#ifdef IS_TEST_NET
  void operator()(const hive::chain::required_automated_actions& req_actions) const
  {
    // Nothing to do.
  }

  void operator()(const hive::chain::optional_automated_actions& opt_actions) const
  {
    // Nothing to do.
  }
#endif

 private:
  int proper_version;
};

void fix_hf_version(hive::plugins::block_api::api_signed_block_object& sb, int proper_hf_version, int block_num)
{
  fix_hf_version_visitor visitor(proper_hf_version);

  for(auto& extension : sb.extensions)
  {
    extension.visit(visitor);
  }
  ilog("Fixing minor hardfork version in extension in block ${block_num}", ("block_num", block_num));
}

std::shared_ptr<hive::chain::full_block_type> from_variant_to_full_block_ptr(const fc::variant& v, int block_num)
{
  hive::plugins::block_api::api_signed_block_object sb;

  fc::from_variant(v, sb);

  switch(block_num)
  {
    // clang-format off
    case 2726331: fix_hf_version(sb, 489, block_num); break;
    case 2730591: fix_hf_version(sb, 118, block_num); break;
    case 2733423: fix_hf_version(sb, 119, block_num); break;
    case 2768535: fix_hf_version(sb, 116, block_num); break;
    case 2781318: fix_hf_version(sb, 116, block_num); break;
    case 2786287: fix_hf_version(sb, 119, block_num); break;
    // clang-format on
  }

  return hive::chain::full_block_type::create_from_signed_block(sb);
}

int consensus_state_provider_get_expected_block_num_impl(const char* context, const char* shared_memory_bin_path)
{
  return initialize_context(context, shared_memory_bin_path);
}


collected_account_balances_collection_t collect_current_all_accounts_balances_impl(const char* context, const char* shared_memory_bin_path)
{
  initialize_context(context, shared_memory_bin_path);
  return collect_current_all_accounts_balances(context);
}


collected_account_balances_collection_t collect_current_account_balances_impl(const std::vector<std::string>& accounts, const char* context, const char* shared_memory_bin_path)
{
  initialize_context(context, shared_memory_bin_path);
  return collect_current_account_balances(accounts, context);
}

void consensus_state_provider_finish_impl(const char* context, const char* shared_memory_bin_path)
{
  if(consensus_state_provider::get_cache().has_context(context))
  {
    hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
    db.close();

    db.chainbase::database::wipe(fc::path(shared_memory_bin_path) / "blockchain");
    consensus_state_provider::get_cache().remove(context);
  }
}

using namespace hive::protocol;

struct conensus_op_visitor_type
{
  conensus_op_visitor_type() {}

  typedef void result_type;

  template <typename T>
  void operator()(const T&) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const account_create_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const account_create_with_delegation_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const account_update_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const account_update2_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const create_claimed_account_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const recover_account_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const pow_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const pow2_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const hardfork_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const transfer_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const transfer_to_vesting_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const account_witness_vote_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const comment_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const vote_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const withdraw_vesting_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const account_witness_proxy_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const feed_publish_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

  void operator()(const witness_update_operation& op) const
  {
    int a = 0;
    a = 1;
    (void)a;
  }

 private:
};

void get_into_op(const pqxx::binarystring& bs)
{
  //_operation* operation_body = PG_GETARG_HIVE_OPERATION_PP( 0 );

  // VARDATA_ANY( operation_body ), VARSIZE_ANY_EXHDR( operation_body ));

  using hive::protocol::operation;

  const char* raw_data = reinterpret_cast<const char*>(bs.data());
  uint32_t data_length = bs.size();

  operation op = fc::raw::unpack_from_char_array<operation>(raw_data, data_length);

  conensus_op_visitor_type conensus_op_visitor;
  op.visit(conensus_op_visitor);

  // note.op.visit( post_operation_visitor( *this ) );
}

// value coming from pxx is without 'T' in the middle to be accepted in variant
std::string fix_pxx_time(const pqxx::field& t)
{
  std::string r = t.c_str();
  r[10] = 'T';
  return r;
}

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h) { return h.c_str() + 2; }

}  // namespace consensus_state_provider
