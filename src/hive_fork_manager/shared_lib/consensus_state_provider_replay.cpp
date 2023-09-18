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
  haf_full_database(csp_session_type* csp_session):csp_session(csp_session){}

  void state_dependent_open( const open_args& args, hive::chain::get_block_by_num_function_type get_block_by_num_function );

  void set_session(csp_session_type* session){csp_session = session;}


  void _push_block_simplified(const std::shared_ptr<full_block_type>& full_block, uint32_t skip);

private:

   csp_session_type* csp_session;

};



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

csp_session_type::csp_session_type(
  const char* context, 
  const char* shared_memory_bin_path,
  const char* postgres_url)
  :
  shared_memory_bin_path(shared_memory_bin_path),
  conn(std::make_unique<postgres_database_helper>(postgres_url)),
  db(std::make_unique<haf_full_database>(this))
  {}



using block_bin_t = hive::plugins::block_api::api_signed_block_object;

// value coming from pxx is without 'T' in the middle to be accepted in variant
std::string fix_pxx_time(const pqxx::field& t);

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h);

class postgres_block_log
{
public:
  void run(csp_session_type* csp_session, int from, int to);
  std::shared_ptr<hive::chain::full_block_type> get_full_block(int block_num, csp_session_type* csp_session);
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
  
  std::shared_ptr<hive::chain::full_block_type> block_to_fullblock(int block_num_from_shared_memory_bin, const pqxx::row& block, csp_session_type* csp_session);
  void measure_before_run();
  void measure_after_run();
  static void handle_exception(std::exception_ptr exception_ptr);
  void get_postgres_data(int from, int to,csp_session_type* csp_session);
  void initialize_iterators();
  void replay_blocks(csp_session_type* csp_session);
  void replay_block(csp_session_type* csp_session, const pqxx::row& block);
  static uint64_t get_skip_flags();
  void apply_full_block(haf_full_database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr, uint64_t skip_flags);
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

   enum : int 
   {
        BLOCK_NUM_EMPTY = -1,
        BLOCK_NUM_MAX = std::numeric_limits<int>::max()
   };
};


void haf_full_database::state_dependent_open( const open_args& args, hive::chain::get_block_by_num_function_type get_head_block_func )
{
    database::state_dependent_open(args, [this](int block_num) 
      { 
        std::shared_ptr<hive::chain::full_block_type> full_block = postgres_block_log().get_full_block(head_block_num(), csp_session);

        return full_block;
      });
}


void undo_blocks(csp_session_type* csp_session, int shift)
{
  hive::chain::database& db = *csp_session->db;
  while(shift > 0)
  {
    db.pop_block();
    shift--;
  }
}



// void undo_blocks(csp_session_type* csp_session , int shift)
// {
//   hive::chain::database& db = *csp_session->db;
//   while(shift > 0)
//   {
//     try
//     {
//       FC_ASSERT(!_pending_tx_session);
//       //_pending_tx_session.reset(); ????
//     }
//     FC_CAPTURE_AND_RETHROW()

//     db.undo();


//     shift--;
//   }
// }


bool consensus_state_provider_replay_impl(csp_session_type* csp_session,  int from, int to)
{

  auto csp_expected_block = consensus_state_provider_get_expected_block_num_impl(csp_session);

  if(from < csp_expected_block)
  {
    undo_blocks(csp_session, csp_expected_block - from);
  }
  else
  {
    from = csp_expected_block;
  }

  if(from != csp_expected_block)
  {
      elog(
          "WARNING: Cannot replay consensus state provider: Initial \"from\" block number is ${from}, but current state is expecting ${curr}",
          ("from", from)("curr", csp_expected_block));
      //return false;
  }

  postgres_block_log().run(csp_session, from, to);
  return true;
}


void postgres_block_log::run(csp_session_type* csp_session, int from, int to)
{
  measure_before_run();

  try
  {
    get_postgres_data(from, to, csp_session);
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

std::shared_ptr<hive::chain::full_block_type> postgres_block_log::block_to_fullblock(int block_num_from_shared_memory_bin, const pqxx::row& block, csp_session_type* csp_session)
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



std::shared_ptr<hive::chain::full_block_type> postgres_block_log::get_full_block(int block_num, csp_session_type*  csp_session)
{
  try
  {
    get_postgres_data(block_num, block_num, csp_session);
    initialize_iterators();
    return block_to_fullblock(block_num, blocks[0], csp_session);
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
  catch( const fc::exception& e )
  {
    elog( "fc::exception ${e}", ("e", e.to_string()) );
  }
  catch( const std::exception& e )
  {
    elog("std::exception e.what=${var1}", ("var1", e.what()));
  }
  catch(...)
  {
    elog("postgres_block_log execution failed: unknown exception.");
  }
}

void postgres_block_log::get_postgres_data(int from, int to, csp_session_type* csp_session)
{
  time_probe get_data_from_postgres_time_probe; get_data_from_postgres_time_probe.start();

  consensus_state_provider::postgres_database_helper& db = *(csp_session->conn);
  
  // clang-format off
    auto blocks_query = "SELECT * FROM hive.blocks_view JOIN hive.accounts_view ON  id = producer_account_id WHERE num >= " 
                                + std::to_string(from) 
                                + " and num <= " 
                                + std::to_string(to) 
                                + " ORDER BY num ASC";
    blocks = db.execute_query(blocks_query);
    std::cout << "Blocks:" << blocks.size() << " "; 

    auto transactions_query = "SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix, expiration, trx_hash, signature FROM hive.transactions_view WHERE block_num >= " 
                                + std::to_string(from) 
                                + " and block_num <= " 
                                + std::to_string(to) 
                                + " ORDER BY block_num, trx_in_block ASC";
    transactions = db.execute_query(transactions_query);
    std::cout << "Transactions:" << transactions.size() << " ";

    auto operations_query = "SELECT block_num, body_binary as bin_body, trx_in_block FROM hive.operations_view WHERE block_num >= " 
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
    // return;
  }

  haf_full_database& db = *csp_session->db;
  std::shared_ptr<hive::chain::full_block_type> fb_ptr;

  block_bin_t signed_block_object = postgres_block_log::block_to_bin(block);
  fb_ptr = from_bin_to_full_block_ptr(signed_block_object, block_num);

  transformations_time_probe.stop();

  apply_full_block(db, fb_ptr, get_skip_flags());
  
}

void postgres_block_log::apply_full_block(haf_full_database& db, const std::shared_ptr<hive::chain::full_block_type>& fb_ptr, uint64_t skip_flags)
{
  apply_full_block_time_probe.start();

  db._push_block_simplified(fb_ptr, skip_flags);

  apply_full_block_time_probe.stop();
}


void haf_full_database::_push_block_simplified(const std::shared_ptr<full_block_type>& full_block, uint32_t skip)
{
  try
  {
    _node_property_object.skip_flags = skip;
    hive::chain::existing_block_flow_control flow_control(full_block);
    push_block(flow_control, skip);

  }FC_CAPTURE_AND_RETHROW() 
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


void initialize_chain_db(csp_session_type* csp_session)
{
  // End of local functions definitions
  // ===================================

  // Main body of the function

  hive::chain::database& db = *csp_session->db;

  db.set_flush_interval(10'000);
  db.set_require_locking(false);

  hive::chain::open_args db_open_args;

  set_open_args_data_dir(db_open_args, csp_session->shared_memory_bin_path.c_str());
  set_open_args_supply(db_open_args);
  set_open_args_other_parameters(db_open_args);
//mtlk here postgres_block_log_has to_be ready

  db.open(db_open_args);
};





csp_session_type* csp_init_impl(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{

  // Dynamically allocate csp_session_type. Ownership transfers to hive.session
  auto csp_session = new csp_session_type(context, shared_memory_bin_path, postgres_url);

  initialize_chain_db(csp_session);

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
  hive::chain::database* db = csp_session->db.get();
  
  db->close();

  if(wipe_clean_shared_memory_bin)
    db->chainbase::database::wipe(fc::path(csp_session->shared_memory_bin_path) / "blockchain");

  delete csp_session;
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


namespace{
 std::unordered_map <std::string,  std::unique_ptr<hive::chain::database>> chain_databases;
}



auto& get_database(csp_session_type* csp_session)
{
    return *csp_session->db;
}

collected_account_balances_t extract_account_balances(
    const hive::chain::account_object* account)
{
  collected_account_balances_t account_balances;
  account_balances.account_name = account->get_name();
  account_balances.balance = account->balance.amount.value;
  account_balances.hbd_balance = account->hbd_balance.amount.value;
  account_balances.vesting_shares = account->vesting_shares.amount.value;
  account_balances.savings_hbd_balance = account->savings_hbd_balance.amount.value;
  account_balances.reward_hbd_balance = account->reward_hbd_balance.amount.value;

  return account_balances;
}

collected_account_balances_collection_t collect_current_account_balances(csp_session_type* csp_session,
                                                                         const std::vector<std::string>& account_names)
{
  auto& db = get_database(csp_session);

  collected_account_balances_collection_t collected_balances;

  for( auto& a : account_names )
  {
    auto acct = db.find< hive::chain::account_object, hive::chain::by_name >( a );
    if( acct != nullptr )
    {
      collected_balances.emplace_back(extract_account_balances(acct));
    }
  }

  return collected_balances;
}

collected_account_balances_collection_t collect_current_all_accounts_balances(csp_session_type* csp_session)
{

  auto& db = get_database(csp_session);

  collected_account_balances_collection_t collected_balances;

  auto& idx = db.get_index< hive::chain::account_index, hive::chain::by_name >();
  auto itr = idx.lower_bound( "" );
  //auto filter = &filter_default< hive::chain::account_object >;
  auto end = idx.end();

  while( itr != end )
  {
    collected_balances.emplace_back(extract_account_balances(&(*itr)));
    ++itr;
  }
  return collected_balances;
}
}  // namespace consensus_state_provider


/*
///////////////////////////////////////////////////////////////

-- Create a PL/pgSQL function to wrap the C++ function and get the connection
CREATE OR REPLACE FUNCTION my_plpgsql_function() RETURNS void AS $$
DECLARE
  conn pg_catalog.pg_stat_activity%ROWTYPE;
BEGIN
  -- Connect to SPI (Server Programming Interface)
  PERFORM SPI_connect();

  -- Get the current PostgreSQL connection
  SELECT * INTO conn FROM pg_catalog.pg_stat_activity WHERE pg_backend_pid() = procpid;
  
  -- Call your C++ function, passing the connection details as needed
  PERFORM my_cpp_function(conn);

  -- Disconnect from SPI
  PERFORM SPI_finish();
END;
$$ LANGUAGE plpgsql;

-- Create a stored procedure that calls the PL/pgSQL function
CREATE OR REPLACE FUNCTION my_stored_procedure() RETURNS void AS $$
BEGIN
  -- Call the PL/pgSQL function to invoke the C++ function
  PERFORM my_plpgsql_function();
END;
$$ LANGUAGE plpgsql;


#include <iostream>
#include <libpq-fe.h>

void my_cpp_function(PGconn* connection) {
    // Check if the connection is valid
    if (connection == nullptr) {
        std::cerr << "Invalid PostgreSQL connection." << std::endl;
        return;
    }

    // Execute a SQL query using the provided connection
    PGresult* result = PQexec(connection, "SELECT * FROM your_table");

    // Check for query execution errors
    if (PQresultStatus(result) != PGRES_TUPLES_OK) {
        std::cerr << "Query execution failed: " << PQerrorMessage(connection) << std::endl;
        PQclear(result);
        return;
    }

    // Process the query result
    int numRows = PQntuples(result);
    int numCols = PQnfields(result);

    for (int row = 0; row < numRows; ++row) {
        for (int col = 0; col < numCols; ++col) {
            const char* value = PQgetvalue(result, row, col);
            std::cout << "Row " << row << ", Column " << col << ": " << value << std::endl;
        }
    }

    // Free the result and close the connection
    PQclear(result);
    PQfinish(connection);
}

int main() {
    // Your main program logic here
    // ...
    
    // Example: Obtain a PostgreSQL connection using libpq
    PGconn* connection = PQconnectdb("dbname=mydb user=myuser password=mypassword host=localhost port=5432");

    // Call your C++ function with the connection
    my_cpp_function(connection);

    return 0;
}



#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <postgresql/libpq-fe.h>

// Function to execute a query and return the result
PGresult* execute_query(PGconn* conn, const char* query) {
    PGresult* result;
    result = PQexec(conn, query);
    if (PQresultStatus(result) != PGRES_TUPLES_OK) {
        fprintf(stderr, "Query execution failed: %s", PQerrorMessage(conn));
        PQclear(result);
        return NULL;
    }
    return result;
}

int main() {
    const char* conninfo = "dbname=mydb user=myuser password=mypassword";
    PGconn* conn = PQconnectdb(conninfo);

    if (PQstatus(conn) == CONNECTION_BAD) {
        fprintf(stderr, "Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return 1;
    }

    int from = 1;
    int to = 10;

    char blocks_query[256];
    snprintf(blocks_query, sizeof(blocks_query), "SELECT * FROM hive.blocks_view JOIN hive.accounts_view ON id = producer_account_id WHERE num >= %d and num <= %d ORDER BY num ASC", from, to);

    PGresult* blocks = execute_query(conn, blocks_query);

    // Process the query result here

    // Don't forget to free the result and close the connection
    PQclear(blocks);
    PQfinish(conn);

    return 0;
}

///////////////////////////////////////////////////////////////
*/


