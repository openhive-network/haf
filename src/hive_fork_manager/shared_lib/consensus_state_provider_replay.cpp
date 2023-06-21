#include "consensus_state_provider_replay.hpp"

#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>
#include <hive/plugins/block_api/block_api_objects.hpp>
#include <hive/protocol/hive_operations.hpp>
#include <iomanip>
#include <limits>
#include <pqxx/pqxx>

#include "fc/time.hpp"
#include "hive/chain/block_log.hpp"
#include "hive/chain/database.hpp"
#include "hive/plugins/database_api/consensus_state_provider_cache.hpp"
#include "hive/protocol/block.hpp"
#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"

#include "hive/protocol/transaction.hpp"
#include "time_probe.hpp"


class postgres_block_log_provider : public hive::chain::block_log
{
 public:
  postgres_block_log_provider(std::string a_context,
                              std::string a_shared_memory_bin_path,
                              std::string a_postgres_url
                              )
      : context(a_context),
        shared_memory_bin_path(a_shared_memory_bin_path),
        postgres_url(a_postgres_url)
  {
  }

  std::string context;
  std::string shared_memory_bin_path;
  std::string postgres_url;

  std::shared_ptr<hive::chain::full_block_type> read_block_by_num(uint32_t block_num) const override;
  // void open(const fc::path& file, bool read_only = false, bool auto_open_artifacts = true) override;
  // void set_compression(bool enabled) override;
  // void set_compression_level(int level) override;
  // std::shared_ptr<hive::chain::full_block_type> head() const override;

  // void for_each_block(uint32_t starting_block_number, uint32_t ending_block_number,
  //                     block_processor_t processor,
  //                     for_each_purpose purpose) const override;

  // void close() override;

  // hive::protocol::block_id_type read_block_id_by_num(uint32_t block_num) const override;
  // std::vector<std::shared_ptr<hive::chain::full_block_type>> read_block_range_by_num(
  //     uint32_t first_block_num, uint32_t count) const override;

  // uint64_t append(const std::shared_ptr<hive::chain::full_block_type>& full_block) override;

  //void flush() override;
};


namespace consensus_state_provider
{

using sbo_t = hive::plugins::block_api::api_signed_block_object;

// value coming from pxx is without 'T' in the middle to be accepted in variant
std::string fix_pxx_time(const pqxx::field& t);

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h);

class postgres_block_log
{
public:
  void run(int from, int to, const char* context, const char* shared_memory_bin_path, const char* postgres_url);
  std::shared_ptr<hive::chain::full_block_type> get_full_block(int block_num,
                              const char* context,
                              const char* shared_memory_bin_path,
                              const char* postgres_url);
private:
  sbo_t build_sbo(const pqxx::row& block, const std::vector<hive::protocol::transaction_id_type>& transaction_ids_sbos, const std::vector<hive::protocol::signed_transaction>& transaction_sbos);
  sbo_t block_to_sbo_with_transactions(const pqxx::row& block);
  std::shared_ptr<hive::chain::full_block_type> from_sbo_to_full_block_ptr(sbo_t& sb, int block_num);

  void build_transaction_ids_sbo(const pqxx::result::const_iterator& transaction,
                                            std::vector<hive::protocol::transaction_id_type>& transaction_id_sbos);

  void transactions2sbo(int block_num, std::vector<hive::protocol::transaction_id_type>& transaction_id_sbos, std::vector<hive::protocol::signed_transaction>& transaction_sbos);
  hive::protocol::signed_transaction build_transaction_sbo(const pqxx::result::const_iterator& transaction, const std::vector<std::string>& signatures, const std::vector<hive::protocol::operation>& operation_sbos);
  std::vector<hive::protocol::operation> operations2sbos(int block_num, int trx_in_block);
  void add_operation_sbo(const pqxx::const_result_iterator& operation, std::vector<hive::protocol::operation>& operation_sbos);
  
  std::shared_ptr<hive::chain::full_block_type> block_to_fullblock(int block_num_from_shared_memory_bin, const pqxx::row& block, const char* context, const char* shared_memory_bin_path, const char* postgres_url);
  void measure_before_run();
  void measure_after_run();
  void handle_exception(std::exception_ptr exception_ptr);
  void get_postgres_data(int from, int to, const char* postgres_url);
  void initialize_iterators();
  void replay_blocks(const char* context, const char* shared_memory_bin_path, const char* postgres_url);
  void replay_block(const pqxx::row& block, const char* context, const char* shared_memory_bin_path, const char* postgres_url);
  static uint64_t get_skip_flags();
  void apply_full_block(hive::chain::database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr, uint64_t skip_flags);
  void measure_before_apply_non_tansactional_operation_block();
  void measure_after_apply_non_tansactional_operation_block();  
  static bool is_current_transaction(const pqxx::result::const_iterator& current_transaction,
                                     const int block_num);
  static std::vector<std::string> build_signatures(const pqxx::result::const_iterator& transaction);
  void rewind_current_operation_to_block(int block_num);
  
  bool is_current_operation(int block_num, int trx_in_block) const;
  static bool operation_matches_block_transaction(const pqxx::const_result_iterator& operation, int block_num, int trx_in_block);

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



bool consensus_state_provider_replay_impl(int from, int to, const char* context,
                                          const char* shared_memory_bin_path, const char* postgres_url)
{
  if(from != consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path, postgres_url))
  {
      elog(
          "ERROR: Cannot replay consensus state provider: Initial \"from\" block number is ${from}, but current state is expecting ${curr}",
          ("from", from)("curr", consensus_state_provider_get_expected_block_num_impl(context, shared_memory_bin_path, postgres_url)));
      return false;
  }

  postgres_block_log().run(from, to, context, shared_memory_bin_path, postgres_url);
  return true;
}

void postgres_block_log::run(int from,
                             int to,
                             const char* context,
                             const char* shared_memory_bin_path,
                             const char* postgres_url)
{
  measure_before_run();

  try
  {
    get_postgres_data(from, to, postgres_url);
    initialize_iterators();
    replay_blocks(context, shared_memory_bin_path, postgres_url);
  }
  catch(...)
  {
    auto current_exception = std::current_exception();
    handle_exception(current_exception);
  }

  measure_after_run();
}

std::shared_ptr<hive::chain::full_block_type> postgres_block_log::block_to_fullblock(int block_num_from_shared_memory_bin, const pqxx::row& block, const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
  auto block_num_from_postgres = block["num"].as<int>();

  if(block_num_from_postgres != block_num_from_shared_memory_bin) 
    return {};

  sbo_t sbo = postgres_block_log::block_to_sbo_with_transactions(block);
  std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_sbo_to_full_block_ptr(sbo, block_num_from_postgres);

  return fb_ptr;
}



std::shared_ptr<hive::chain::full_block_type> postgres_block_log::get_full_block(int block_num,
                             const char* context,
                             const char* shared_memory_bin_path,
                             const char* postgres_url)
{
  try
  {
    get_postgres_data(block_num, block_num, postgres_url);
    initialize_iterators();
    return block_to_fullblock(block_num, blocks[0], context, shared_memory_bin_path, postgres_url);
  }
  catch(...)
  {
    auto current_exception = std::current_exception();
    handle_exception(current_exception);
  }
  return {};
}

void postgres_block_log::measure_before_run()
{
  transformations_time_probe.reset();
  apply_full_block_time_probe.reset();
}

void postgres_block_log::measure_after_run()
{
  transformations_time_probe.print_duration("Transformations");
  apply_full_block_time_probe.print_duration("Transactional_apply_block");
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

void postgres_block_log::replay_blocks(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
  for(const auto& block : blocks)
  {
    replay_block(block, context, shared_memory_bin_path, postgres_url);
  }
}


void postgres_block_log::replay_block(const pqxx::row& block, const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
  transformations_time_probe.start();
  

  auto block_num = block["num"].as<int>();

  if(block_num != initialize_context(context, shared_memory_bin_path, postgres_url)) 
    return;

  hive::chain::database& db = consensus_state_provider::get_cache().get_db(context);
  std::shared_ptr<hive::chain::full_block_type> fb_ptr;

  sbo_t sbo = postgres_block_log::block_to_sbo_with_transactions(block);
  fb_ptr = from_sbo_to_full_block_ptr(sbo, block_num);

  transformations_time_probe.stop();

  apply_full_block(db, fb_ptr, get_skip_flags());
  
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




sbo_t postgres_block_log::block_to_sbo_with_transactions(const pqxx::row& block)
{
  auto block_num = block["num"].as<int>();

  std::vector<hive::protocol::transaction_id_type> transaction_ids_sbos;
  std::vector<hive::protocol::signed_transaction> transaction_sbos;
  
  if(block_num == current_transaction_block_num()) 
    transactions2sbo(block_num, transaction_ids_sbos, transaction_sbos);
  
  return build_sbo(block, transaction_ids_sbos, transaction_sbos);

}

template<typename INT, typename T>
void i2v(INT s, T& val)
{

  T::Nonexistent_Type = 0; // This line will cause a compile error

  fc::variant vo;
  to_variant(s, vo);
  from_variant(vo, val);
}

template<>
void i2v(int i, unsigned short& val)
{
  val = i;
}


template<>
void i2v(int long i, unsigned int& val)
{
  val = i;
}


template<typename T>
void s2v(const std::string s, T& val)
{

  T::Nonexistent_Type = 0; // This line will cause a compile error

  fc::variant vo;
  to_variant(s, vo);
  from_variant(vo, val);
}


template<>
void s2v(const std::string str, fc::ripemd160& bi)
{

  std::vector<char> vo;
  vo.resize( str.size() / 2 );
  if( vo.size() )
  {
      size_t r = fc::from_hex( str, vo.data(), vo.size() );
      FC_ASSERT( r == vo.size() );
  }

  if( vo.size() )
  {
      memcpy(&bi, vo.data(), fc::min<size_t>(vo.size(),sizeof(bi)) );
  }
  else
      memset( static_cast<void*>(&bi), char(0), sizeof(bi) );
}


template<>
void s2v(const std::string s, fc::time_point_sec& t)
{
  t = fc::time_point_sec::from_iso_string( s );
}

template<>
void s2v(const std::string s, std::string& val)
{
  val =s;
}


template<>
void s2v(const std::string s, hive::protocol::public_key_type& val)
{
   val = hive::protocol::public_key_type(s);
}

// mtlk TODO - similar function above
template<>
void s2v(const std::string str, hive::chain::signature_type& bi) // fc::array<unsigned char, 65>’
{
  std::vector<char> vo;
  vo.resize( str.size() / 2 );
  if( vo.size() )
  {
      size_t r = fc::from_hex( str, vo.data(), vo.size() );
      FC_ASSERT( r == vo.size() );
  }

  if( vo.size() )
  {
      memcpy(&bi, vo.data(), fc::min<size_t>(vo.size(),sizeof(bi)) );
  }
  else
      memset( static_cast<void*>(&bi), char(0), sizeof(bi) );

}

template<typename T>
void p2b_hex_to_ripemd160(const char* field_name, const T& block_or_transaction, fc::ripemd160& val)
{
  s2v(fix_pxx_hex(block_or_transaction[field_name]), val);
}

template<typename T>
void p2b_time_to_time_point_sec(const char* field_name, const T& block_or_transaction, fc::time_point_sec& val)
{
  s2v(fix_pxx_time(block_or_transaction[field_name]), val);
}

}

sbo_t postgres_block_log::build_sbo(const pqxx::row& block, const std::vector<hive::protocol::transaction_id_type>& transaction_ids_sbos, const std::vector<hive::protocol::signed_transaction>& transaction_sbos)
{
  using namespace hive::protocol;
  using std::string;
  using std::vector;

  sbo_t sb;

  p2b_hex_to_ripemd160("prev", block, sb.previous);
  p2b_time_to_time_point_sec("created_at", block, sb.timestamp);
  s2v(block["name"].c_str(), sb.witness);
  p2b_hex_to_ripemd160("transaction_merkle_root", block, sb.transaction_merkle_root);
 
  if(const auto& field = block["extensions"]; !field.is_null())
  {
    //It seems reasonable to use existing conversion to static_variant via variant here, or maybe add a method to json.cpp ? mtlk TODO
    std::string json = field.c_str();
    fc::variant extensions = fc::json::from_string(json);
    from_variant(extensions, sb.extensions);
  }
    
  s2v(fix_pxx_hex(block["witness_signature"]), sb.witness_signature);


  p2b_hex_to_ripemd160("hash", block, sb.block_id);
  s2v(block["signing_key"].c_str(), sb.signing_key);

  sb.transaction_ids = std::move(transaction_ids_sbos);

  sb.transactions = std::move(transaction_sbos);

  return sb;
}

void postgres_block_log::transactions2sbo(int block_num, std::vector<hive::protocol::transaction_id_type>& transaction_id_sbos, std::vector<hive::protocol::signed_transaction>& transaction_sbos)
{
  for(; current_transaction != transactions.end() && is_current_transaction(current_transaction, block_num); ++current_transaction)
  {
    auto trx_in_block = current_transaction["trx_in_block"].as<int>();

    std::vector<std::string> signatures = build_signatures(current_transaction);

    build_transaction_ids_sbo(current_transaction, transaction_id_sbos);

    rewind_current_operation_to_block(block_num);

    std::vector<hive::protocol::operation> operation_sbos = operations2sbos(block_num, trx_in_block);

    hive::protocol::signed_transaction transaction_sbo = build_transaction_sbo(current_transaction, signatures, operation_sbos);

    transaction_sbos.emplace_back(transaction_sbo);
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

void postgres_block_log::build_transaction_ids_sbo(const pqxx::result::const_iterator& transaction,
                                            std::vector<hive::protocol::transaction_id_type>& transaction_id_sbos)
{
  //  https://github.com/jtv/libpqxx/blob/3d97c80bcde96fb70a21c1ae1cf92ad934818210/include/pqxx/field.hxx
  //   Do not use this for BYTEA values, or other binary values.  To read those,
  //   convert the value to your desired type using `to()` or `as()`.  For
  //   example: `f.as<std::basic_string<std::byte>>()`.
  //
  // [[nodiscard]] PQXX_PURE char const *c_str() const &;

  hive::protocol::transaction_id_type transaction_id_sbo;
  p2b_hex_to_ripemd160("trx_hash", transaction, transaction_id_sbo);

  transaction_id_sbos.push_back(transaction_id_sbo);
}

void postgres_block_log::rewind_current_operation_to_block(int block_num)
{
  while(current_operation_block_num() < block_num && current_operation != operations.end())
  {
    ++current_operation;
  }
};

hive::protocol::signed_transaction postgres_block_log::build_transaction_sbo(const pqxx::result::const_iterator& transaction, const std::vector<std::string>& signatures, const std::vector<hive::protocol::operation>& operation_sbos)
{
  hive::protocol::signed_transaction  signed_transaction;

  i2v(transaction["ref_block_num"].as<int>(), signed_transaction.ref_block_num);
  i2v(transaction["ref_block_prefix"].as<int64_t>() ,signed_transaction.ref_block_prefix);
  p2b_time_to_time_point_sec("expiration", transaction, signed_transaction.expiration);
  
  for(const auto& a_signature : signatures)
  {
    hive::protocol::signature_type signature;
    s2v(a_signature, signature);
    signed_transaction.signatures.push_back(signature);
  }

  for(const auto&  op : operation_sbos)
  {
    signed_transaction.operations.push_back(op);
  }

  return signed_transaction;
}

bool postgres_block_log::is_current_operation(int block_num, int trx_in_block) const
{
  return block_num == current_operation_block_num() && trx_in_block == current_operation_trx_num();
}

bool postgres_block_log::operation_matches_block_transaction(const pqxx::const_result_iterator& operation, int block_num, int trx_in_block) 
{
  return operation["block_num"].as<int>() == block_num && operation["trx_in_block"].as<int>() == trx_in_block;
}

std::vector<hive::protocol::operation> postgres_block_log::operations2sbos(int block_num, int trx_in_block)
{
  std::vector<hive::protocol::operation> operation_sbos;
  if(is_current_operation(block_num, trx_in_block))
  {
    for(; current_operation != operations.end() && operation_matches_block_transaction(current_operation, block_num, trx_in_block);
        ++current_operation)
    {
      add_operation_sbo(current_operation, operation_sbos);
    }
  }
  return operation_sbos;
}


void postgres_block_log::add_operation_sbo(const pqxx::const_result_iterator& cur_op, std::vector<hive::protocol::operation>& operation_sbos)
{
  pqxx::binarystring bs(cur_op["bin_body"]);
  const char* raw_data = reinterpret_cast<const char*>(bs.data());
  uint32_t data_length = bs.size();

  operation_sbos.push_back(fc::raw::unpack_from_char_array<hive::protocol::operation>(raw_data, data_length));
}

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
  db_open_args.force_replay = false;
};


auto initialize_chain_db = [](hive::chain::database& db, const char* context, const char* shared_memory_bin_path)
{
  // End of local functions definitions
  // ===================================

  // Main body of the function
  db.set_flush_interval(10'000);
  db.set_require_locking(false);

  hive::chain::open_args db_open_args;

  set_open_args_data_dir(db_open_args, shared_memory_bin_path);
  set_open_args_supply(db_open_args);
  set_open_args_other_parameters(db_open_args);
//mtlk here postgres_block_log_has to_be ready

  db.open(db_open_args);
};

auto create_and_init_database = [](const char* context, const char* shared_memory_bin_path, const char* postgres_url) -> hive::chain::database*
{
  
  auto b = std::make_unique<postgres_block_log_provider>(context, shared_memory_bin_path, postgres_url);
  hive::chain::database* db = new hive::chain::database(std::move(b));
  initialize_chain_db(*db, context, shared_memory_bin_path);
  consensus_state_provider::get_cache().add(context, db);
  return db;
};



int initialize_context(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{

  hive::chain::database* db;

  if(!consensus_state_provider::get_cache().has_context(context))
  {
    db = create_and_init_database(context, shared_memory_bin_path, postgres_url);
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

void fix_hf_version(sbo_t& sb, int proper_hf_version, int block_num)
{
  fix_hf_version_visitor visitor(proper_hf_version);

  for(auto& extension : sb.extensions)
  {
    extension.visit(visitor);
  }
  ilog("Fixing minor hardfork version in extension in block ${block_num}", ("block_num", block_num));
}


std::shared_ptr<hive::chain::full_block_type> postgres_block_log::from_sbo_to_full_block_ptr(sbo_t& sb, int block_num)
{
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

int consensus_state_provider_get_expected_block_num_impl(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
  return initialize_context(context, shared_memory_bin_path, postgres_url);
}


collected_account_balances_collection_t collect_current_all_accounts_balances_impl(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
  initialize_context(context, shared_memory_bin_path, postgres_url);
  return collect_current_all_accounts_balances(context);
}


collected_account_balances_collection_t collect_current_account_balances_impl(const std::vector<std::string>& accounts, const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
  initialize_context(context, shared_memory_bin_path, postgres_url);
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


// value coming from pxx is without 'T' in the middle to be accepted in our time consumer
std::string fix_pxx_time(const pqxx::field& t)
{
  const auto T_letter_position_in_ascii_time_string = 10;
  std::string r = t.c_str();
  r[T_letter_position_in_ascii_time_string] = 'T';
  return r;
}

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h) 
{
  const auto backslash_x_prefix_length = 2; 
  return h.c_str() + backslash_x_prefix_length; 
}

}  // namespace consensus_state_provider


std::shared_ptr<hive::chain::full_block_type> postgres_block_log_provider::read_block_by_num(uint32_t block_num) const
{
  return consensus_state_provider::postgres_block_log().get_full_block(block_num, context.c_str(), shared_memory_bin_path.c_str(), postgres_url.c_str());
}
