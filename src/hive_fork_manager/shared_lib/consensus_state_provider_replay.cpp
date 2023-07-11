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
#include "hive/protocol/block.hpp"
#include "hive/protocol/forward_impacted.hpp"
#include "hive/protocol/operations.hpp"

#include "hive/protocol/transaction.hpp"
#include "time_probe.hpp"



#define myASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            std::cerr << "Assertion `" #condition "` failed in " << __FILE__ \
                      << " line " << __LINE__ << ": " << message << std::endl; \
            exit(EXIT_FAILURE); \
        } \
    } while (0)


namespace consensus_state_provider
{

using hive::chain::open_args;
using hive::chain::full_block_type;
using hive::chain::block_id_type;



class haf_full_database : public hive::chain::database
{
  public:
    haf_full_database(const char* a_context, const char* a_shared_memory_bin_path, const char* a_postgres_url)
      :
      context(a_context),
      shared_memory_bin_path(a_shared_memory_bin_path),
      postgres_url(a_postgres_url)
    {

    }
  private:
   std:: string context, shared_memory_bin_path, postgres_url;


public:
  bool is_reindex_complete( uint64_t* head_block_num_origin, uint64_t* head_block_num_state ) const override{myASSERT(0, "STOP mtlk");}
  uint32_t reindex( const open_args& args ) override{myASSERT(0, "STOP mtlk");}
  void close(bool rewind = true) override{myASSERT(1, "STOP mtlk");}
private:
  bool is_known_block( const block_id_type& id )const override{myASSERT(0, "STOP mtlk");}
  bool is_known_block_unlocked(const block_id_type& id)const override{myASSERT(0, "STOP mtlk");}
  block_id_type              find_block_id_for_num( uint32_t block_num )const override{myASSERT(0, "STOP mtlk");}
  std::vector<std::shared_ptr<full_block_type>>  fetch_block_range( const uint32_t starting_block_num, const uint32_t count, 
                                                                      fc::microseconds wait_for_microseconds = fc::microseconds() ) override{myASSERT(0, "STOP mtlk");}
  std::shared_ptr<full_block_type> fetch_block_by_number( uint32_t num, fc::microseconds wait_for_microseconds = fc::microseconds() )const override{myASSERT(0, "STOP mtlk");}
  
  std::shared_ptr<full_block_type> fetch_block_by_id(const block_id_type& id)const override{myASSERT(0, "STOP mtlk");}
  
  void migrate_irreversible_state(uint32_t old_last_irreversible) override{myASSERT(1, "STOP mtlk");}
  
  std::vector<block_id_type> get_blockchain_synopsis(const block_id_type& reference_point, uint32_t number_of_blocks_after_reference_point) override{myASSERT(0, "STOP mtlk");}
  bool is_included_block_unlocked(const block_id_type& block_id) override{myASSERT(0, "STOP mtlk");}
  std::vector<block_id_type> get_block_ids(const std::vector<block_id_type>& blockchain_synopsis, uint32_t& remaining_item_count, uint32_t limit) override{myASSERT(0, "STOP mtlk");}

  std::shared_ptr<full_block_type> get_head_block() const override;

  void open_block_log(const open_args& args) override
  {
    // Intentionally empty
  } 

};




using block_bin_t = hive::plugins::block_api::api_signed_block_object;

// value coming from pxx is without 'T' in the middle to be accepted in variant
std::string fix_pxx_time(const pqxx::field& t);

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h);

class postgres_block_log
{
public:
  void run(csp_session_type* csp_session, int from, int to);
  std::shared_ptr<hive::chain::full_block_type> get_full_block(int block_num,
                              const char* context,
                              const char* shared_memory_bin_path,
                              const char* postgres_url);
private:
  static block_bin_t build_block_bin(const pqxx::row& block, std::vector<hive::protocol::transaction_id_type> transaction_id_bins, std::vector<hive::protocol::signed_transaction> transaction_bins);
  block_bin_t block_to_bin(const pqxx::row& block);
  static std::shared_ptr<hive::chain::full_block_type> from_bin_to_full_block_ptr(block_bin_t& sb, int block_num);

  static void build_transaction_id_bins(const pqxx::result::const_iterator& transaction,
                                            std::vector<hive::protocol::transaction_id_type>& transaction_id_bins);

  void transactions2bin(int block_num, std::vector<hive::protocol::transaction_id_type>& transaction_id_bins, std::vector<hive::protocol::signed_transaction>& transaction_bins);
  static hive::protocol::signed_transaction build_transaction_bin(const pqxx::result::const_iterator& transaction, std::vector<hive::protocol::signature_type> signatures, std::vector<hive::protocol::operation> operation_bins);
  std::vector<hive::protocol::operation> operations2bins(int block_num, int trx_in_block);
  static void add_operation_bin(const pqxx::const_result_iterator& operation, std::vector<hive::protocol::operation>& operation_bins);
  
  std::shared_ptr<hive::chain::full_block_type> block_to_fullblock(int block_num_from_shared_memory_bin, const pqxx::row& block, const char* context, const char* shared_memory_bin_path, const char* postgres_url);
  void measure_before_run();
  void measure_after_run();
  static void handle_exception(std::exception_ptr exception_ptr);
  void get_postgres_data(int from, int to, const char* postgres_url);
  void initialize_iterators();
  void replay_blocks(csp_session_type* csp_session);
  void replay_block(csp_session_type* csp_session, const pqxx::row& block);
  static uint64_t get_skip_flags();
  void apply_full_block(hive::chain::database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr, uint64_t skip_flags);
  void measure_before_apply_non_tansactional_operation_block();
  void measure_after_apply_non_tansactional_operation_block();  
  static bool is_current_transaction(const pqxx::result::const_iterator& current_transaction,
                                     const int block_num);
  static std::vector<hive::protocol::signature_type> build_signatures(const pqxx::result::const_iterator& transaction);
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
  std::chrono::nanoseconds transformations_duration{};
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

   enum : int 
   {
        BLOCK_NUM_EMPTY = -1,
        BLOCK_NUM_MAX = std::numeric_limits<int>::max()
   };
};

std::shared_ptr<full_block_type> haf_full_database::get_head_block() const
{
    std::shared_ptr<hive::chain::full_block_type> fb_ptr = 
          postgres_block_log().
          get_full_block(this->head_block_num(), context.c_str(), shared_memory_bin_path.c_str(), postgres_url.c_str());
    return fb_ptr;
  
}


bool consensus_state_provider_replay_impl(csp_session_type* csp_session,  int from, int to)
{
  if(from != consensus_state_provider_get_expected_block_num_impl(csp_session))
  {
      elog(
          "ERROR: Cannot replay consensus state provider: Initial \"from\" block number is ${from}, but current state is expecting ${curr}",
          ("from", from)("curr", consensus_state_provider_get_expected_block_num_impl(csp_session)));
      return false;
  }

  postgres_block_log().run(csp_session, from, to);
  return true;
}


void postgres_block_log::run(csp_session_type* csp_session, int from, int to)
{
  measure_before_run();

  try
  {
    get_postgres_data(from, to, csp_session->postgres_url.c_str());
    initialize_iterators();
    replay_blocks(csp_session);
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
  {
    return {};
  }

  block_bin_t signed_block_object = postgres_block_log::block_to_bin(block);
  std::shared_ptr<hive::chain::full_block_type> fb_ptr = from_bin_to_full_block_ptr(signed_block_object, block_num_from_postgres);

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

void postgres_block_log::replay_blocks(csp_session_type* csp_session)
{
  for(const auto& block : blocks)
  {
    replay_block(csp_session, block);
  }
}


void postgres_block_log::replay_block(csp_session_type* csp_session, const pqxx::row& block)
{
  transformations_time_probe.start();
  

  auto block_num = block["num"].as<int>();

  if(block_num !=  consensus_state_provider_get_expected_block_num_impl(csp_session)) 
  {
    return;
  }

  hive::chain::database& db = *csp_session->db;
  std::shared_ptr<hive::chain::full_block_type> fb_ptr;

  block_bin_t signed_block_object = postgres_block_log::block_to_bin(block);
  fb_ptr = from_bin_to_full_block_ptr(signed_block_object, block_num);

  transformations_time_probe.stop();

  apply_full_block(db, fb_ptr, get_skip_flags());
  
}

void postgres_block_log::apply_full_block(hive::chain::database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr,
                                       uint64_t skip_flags)
{
  apply_full_block_time_probe.start();

  db.set_tx_status(hive::chain::database::TX_STATUS_BLOCK);
  db.public_reset_fork_db();    // override effect of _fork_db.start_block() call in open()

  db.public_apply_block(fb_ptr, skip_flags);
  db.clear_tx_status();
  db.set_revision(db.head_block_num());

  apply_full_block_time_probe.stop();
}




block_bin_t postgres_block_log::block_to_bin(const pqxx::row& block)
{
  auto block_num = block["num"].as<int>();

  std::vector<hive::protocol::transaction_id_type> transaction_id_bins;
  std::vector<hive::protocol::signed_transaction> transaction_bins;

  if(block_num == current_transaction_block_num())
  {
    transactions2bin(block_num, transaction_id_bins, transaction_bins);
  }

  return build_block_bin(block, std::move(transaction_id_bins), std::move(transaction_bins));

}


template<typename T>
void hex_to_binary(const std::string& str, T& binary)
{
  std::vector<char> buffer;
  buffer.resize( str.size() / 2 );
  if( !buffer.empty() )
  {
      size_t r = fc::from_hex( str, buffer.data(), buffer.size() );
      FC_ASSERT( r == buffer.size() );
  }

  if( !buffer.empty() )
  {
      memcpy(&binary, buffer.data(), fc::min<size_t>(buffer.size(),sizeof(binary)) );
  }
  else 
  {
      memset( static_cast<void*>(&binary), static_cast<char>(0), sizeof(binary) );
  }

}


template <typename T>
void p2b_hex_to_ripemd160(const char* field_name, const T& block_or_transaction, fc::ripemd160& val)
{
  hex_to_binary(fix_pxx_hex(block_or_transaction[field_name]), val);
}


template <typename T>
void p2b_hex_to_signature_type(const char* field_name, const T& block_or_transaction, hive::chain::signature_type& val)
{
  hex_to_binary(fix_pxx_hex(block_or_transaction[field_name]), val);
}

template <typename T>
void p2b_time_to_time_point_sec(const char* field_name, const T& block_or_transaction, fc::time_point_sec& val)
{
  val = fc::time_point_sec::from_iso_string( fix_pxx_time(block_or_transaction[field_name]) );

}

template <typename T>
void p2b_cstr_to_public_key(const char* field_name, const T& block_or_transaction, hive::chain::public_key_type& val)
{
  val = hive::protocol::public_key_type(block_or_transaction[field_name].c_str());
}

template <typename T>
void p2b_cstr_to_str(const char* field_name, const T& block_or_transaction, std::string& val)
{
  val = block_or_transaction[field_name].c_str();
}

template <typename T>
void p2b_int_to_uint16(const char* field_name, const T& block_or_transaction, uint16_t& val)
{
  val = block_or_transaction[field_name]. template as<int>();
}

template <typename T>
void p2b_int64_to_uint32(const char* field_name, const T& block_or_transaction, uint32_t& val)
{
  val = block_or_transaction[field_name]. template as<int64_t>();
}



block_bin_t postgres_block_log::build_block_bin(const pqxx::row& block, std::vector<hive::protocol::transaction_id_type> transaction_id_bins, std::vector<hive::protocol::signed_transaction> transaction_bins)
{
  using std::string;
  using std::vector;

  block_bin_t sb;

  p2b_hex_to_ripemd160("prev", block, sb.previous);
  p2b_time_to_time_point_sec("created_at", block, sb.timestamp);
  p2b_cstr_to_str("name", block, sb.witness);
  p2b_hex_to_ripemd160("transaction_merkle_root", block, sb.transaction_merkle_root);
 
  if(const auto& field = block["extensions"]; !field.is_null())
  {
    //It seems reasonable to use existing conversion to static_variant via variant here, or maybe add a method to json.cpp ? mtlk TODO
    std::string json = field.c_str();
    fc::variant extensions = fc::json::from_string(json);
    from_variant(extensions, sb.extensions);
  }
    
  p2b_hex_to_signature_type("witness_signature", block,  sb.witness_signature);


  p2b_hex_to_ripemd160("hash", block, sb.block_id);
  p2b_cstr_to_public_key("signing_key", block, sb.signing_key);

  sb.transaction_ids = std::move(transaction_id_bins);

  sb.transactions = std::move(transaction_bins);

  return sb;
}

void postgres_block_log::transactions2bin(int block_num, std::vector<hive::protocol::transaction_id_type>& transaction_id_bins, std::vector<hive::protocol::signed_transaction>& transaction_bins)
{
  for(; current_transaction != transactions.end() && is_current_transaction(current_transaction, block_num); ++current_transaction)
  {
    auto trx_in_block = current_transaction["trx_in_block"].as<int>();

    std::vector<hive::protocol::signature_type> signatures = build_signatures(current_transaction);

    build_transaction_id_bins(current_transaction, transaction_id_bins);

    rewind_current_operation_to_block(block_num);

    std::vector<hive::protocol::operation> operation_bins = operations2bins(block_num, trx_in_block);

    hive::protocol::signed_transaction transaction_bin = build_transaction_bin(current_transaction, std::move(signatures), std::move(operation_bins));

    transaction_bins.emplace_back(transaction_bin);
  }
}

bool postgres_block_log::is_current_transaction(const pqxx::result::const_iterator& current_transaction, const int block_num)
{
  return current_transaction["block_num"].as<int>() == block_num;
}

std::vector<hive::protocol::signature_type> postgres_block_log::build_signatures(const pqxx::result::const_iterator& transaction)
{
  std::vector<hive::protocol::signature_type> signatures;
  if(!transaction["signature"].is_null())
  {
    hive::protocol::signature_type signature;
    p2b_hex_to_signature_type("signature", transaction, signature);
    signatures.push_back(signature);
  }
  return signatures;
}

void postgres_block_log::build_transaction_id_bins(const pqxx::result::const_iterator& transaction,
                                            std::vector<hive::protocol::transaction_id_type>& transaction_id_bins)
{
  //  https://github.com/jtv/libpqxx/blob/3d97c80bcde96fb70a21c1ae1cf92ad934818210/include/pqxx/field.hxx
  //   Do not use this for BYTEA values, or other binary values.  To read those,
  //   convert the value to your desired type using `to()` or `as()`.  For
  //   example: `f.as<std::basic_string<std::byte>>()`.
  //
  // [[nodiscard]] PQXX_PURE char const *c_str() const &;

  hive::protocol::transaction_id_type transaction_id_bin;
  p2b_hex_to_ripemd160("trx_hash", transaction, transaction_id_bin);

  transaction_id_bins.push_back(transaction_id_bin);
}

void postgres_block_log::rewind_current_operation_to_block(int block_num)
{
  while(current_operation_block_num() < block_num && current_operation != operations.end())
  {
    ++current_operation;
  }
};



hive::protocol::signed_transaction postgres_block_log::build_transaction_bin(const pqxx::result::const_iterator& transaction, std::vector<hive::protocol::signature_type> signatures, std::vector<hive::protocol::operation> operation_bins)
{
  hive::protocol::signed_transaction  signed_transaction;

  p2b_int_to_uint16("ref_block_num", transaction, signed_transaction.ref_block_num);
  p2b_int64_to_uint32("ref_block_prefix", transaction, signed_transaction.ref_block_prefix);
  p2b_time_to_time_point_sec("expiration", transaction, signed_transaction.expiration);
  
  signed_transaction.signatures = std::move(signatures);

  signed_transaction.operations = std::move(operation_bins);

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

std::vector<hive::protocol::operation> postgres_block_log::operations2bins(int block_num, int trx_in_block)
{
  std::vector<hive::protocol::operation> operation_bins;
  if(is_current_operation(block_num, trx_in_block))
  {
    for(; current_operation != operations.end() && operation_matches_block_transaction(current_operation, block_num, trx_in_block);
        ++current_operation)
    {
      add_operation_bin(current_operation, operation_bins);
    }
  }
  return operation_bins;
}


void postgres_block_log::add_operation_bin(const pqxx::const_result_iterator& operation, std::vector<hive::protocol::operation>& operation_bins)
{
  pqxx::binarystring bs(operation["bin_body"]);
  const unsigned char* raw_data = bs.data();
  auto data_length = bs.size();

  operation_bins.push_back(fc::raw::unpack_from_char_array<hive::protocol::operation>(reinterpret_cast<const char*>(raw_data), data_length));
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

void set_open_args_data_dir(hive::chain::open_args& db_open_args, const char* shared_memory_bin_path)
{
  db_open_args.data_dir = shared_memory_bin_path;
  db_open_args.shared_mem_dir = db_open_args.data_dir / "blockchain";
};

void set_open_args_supply(hive::chain::open_args& db_open_args)
{
  db_open_args.initial_supply = HIVE_INIT_SUPPLY;
  db_open_args.hbd_initial_supply = HIVE_HBD_INIT_SUPPLY;
};

void set_open_args_other_parameters(hive::chain::open_args& db_open_args)
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


void initialize_chain_db(hive::chain::database& db, const char* context, const char* shared_memory_bin_path, const char* postgres_url)
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


hive::chain::database* create_and_init_database(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
  auto* db = new haf_full_database(context, shared_memory_bin_path, postgres_url);
  initialize_chain_db(*db, context, shared_memory_bin_path, postgres_url);
  return db;
};



csp_session_type* csp_init_impl(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{
    hive::chain::database* db = create_and_init_database(context, shared_memory_bin_path, postgres_url);
    auto* csp_session =  new csp_session_type{context, shared_memory_bin_path, postgres_url, db};
    return csp_session;
}

struct fix_hf_version_visitor
{
  explicit fix_hf_version_visitor(int a_proper_version) : proper_version(a_proper_version) {}

  using result_type = void;

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


 private:
  int proper_version;
};

void fix_hf_version(block_bin_t& sb, int proper_hf_version, int block_num)
{
  fix_hf_version_visitor visitor(proper_hf_version);

  for(auto& extension : sb.extensions)
  {
    extension.visit(visitor);
  }
  ilog("Fixing minor hardfork version in extension in block ${block_num}", ("block_num", block_num));
}


std::shared_ptr<hive::chain::full_block_type> postgres_block_log::from_bin_to_full_block_ptr(block_bin_t& sb, int block_num)
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

int consensus_state_provider_get_expected_block_num_impl(csp_session_type* csp_session)
{
  return csp_session->db->head_block_num() + 1;
}



collected_account_balances_collection_t collect_current_all_accounts_balances_impl(csp_session_type* csp_session)
{
  return collect_current_all_accounts_balances(csp_session);
}


collected_account_balances_collection_t collect_current_account_balances_impl(csp_session_type* csp_session, const std::vector<std::string>& accounts)
{
  return collect_current_account_balances(csp_session, accounts);
}

void csp_finish_impl(csp_session_type* csp_session, bool wipe_clean_shared_memory_bin)
{
  hive::chain::database* db = csp_session->db;
  
  db->close();

  if(wipe_clean_shared_memory_bin)
    db->chainbase::database::wipe(fc::path(csp_session->shared_memory_bin_path) / "blockchain");

  delete db;
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
