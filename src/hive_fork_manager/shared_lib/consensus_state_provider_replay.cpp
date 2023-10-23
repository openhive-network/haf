#include "consensus_state_provider_replay.hpp"
#include "time_probe.hpp"

#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>
#include "fc/time.hpp"
#include <hive/plugins/block_api/block_api_objects.hpp>

#include <pqxx/pqxx>

#include <iomanip>
#include <limits>

namespace consensus_state_provider
{

const uint64_t CSP_SHARED_MEMORY_SIZE = 24*1024*1024*1024ull;

using hive::chain::open_args;
using hive::chain::full_block_type;
using hive::chain::block_id_type;
using hive::chain::get_block_by_num_function_type;
using hive::chain::open_args;
using full_block_ptr = std::shared_ptr<full_block_type>;


//This is the override class of the chain::database used in consensus_state_provide - more info mtlk todo
class haf_state_database : public hive::chain::database
{
public:
  haf_state_database(csp_session_ref_type csp_session):csp_session(csp_session){}

  virtual void state_dependent_open( const open_args& args ) override;

  void push_haf_block(const full_block_ptr& full_block, uint32_t skip);

private:

   csp_session_ref_type csp_session;

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
  db(std::make_unique<haf_state_database>(*this))
  {}



using block_bin_t = hive::plugins::block_api::api_signed_block_object;


class postgres_block_log
{
public:
  explicit postgres_block_log(csp_session_ref_type csp_session):csp_session(csp_session){}
  void run(int first_block, int last_block);
  full_block_ptr read_full_block(int block_num);
private:
  void prepare_postgres_data(int first_block, int last_block);
  void replay_blocks();
  void replay_block(const pqxx::row& block);
  void replay_full_block(haf_state_database& db, const full_block_ptr& fb_ptr, uint64_t skip_flags);

  void read_postgres_data(int first_block, int last_block);
  void initialize_iterators();

  full_block_ptr block_to_fullblock(int block_num_from_shared_memory_bin, const pqxx::row& block);

  block_bin_t block_to_bin(const pqxx::row& block);
  void transactions2bin(int block_num, std::vector<hive::protocol::transaction_id_type>& transaction_id_bins, std::vector<hive::protocol::signed_transaction>& transaction_bins);
  std::vector<hive::protocol::operation> operations2bins(int block_num, int trx_in_block);

  void measure_before_run();
  void measure_after_run();
  void rewind_current_operation_to_block(int block_num);

  bool is_current_operation(int block_num, int trx_in_block) const;
  bool current_transaction_belongs_to_block(const int block_num);

  int current_transaction_block_num();
  int current_operation_block_num() const;
  int current_operation_trx_num() const;

  csp_session_ref_type csp_session;

  pqxx::result blocks;
  pqxx::result transactions;
  pqxx::result operations;
  pqxx::result::const_iterator current_transaction;
  pqxx::result::const_iterator current_operation;
  time_probe transformations_time_probe;
  time_probe replay_full_block_time_probe;

  enum : int
  {
      BLOCK_NUM_EMPTY = -1,
      BLOCK_NUM_MAX = std::numeric_limits<int>::max()
  };
};


void undo_blocks(csp_session_ref_type, int shift);
void initialize_chain_db(csp_session_ref_type csp_session);

void set_open_args_data_dir(open_args& db_open_args, const std::string&  shared_memory_bin_path);
void set_open_args_other_parameters(open_args& db_open_args);

//lower level helpers
void handle_exception(std::exception_ptr exception_ptr);
uint64_t get_skip_flags();
block_bin_t build_block_bin(const pqxx::row& block, std::vector<hive::protocol::transaction_id_type> transaction_id_bins, std::vector<hive::protocol::signed_transaction> transaction_bins);
full_block_ptr from_bin_to_full_block_ptr(block_bin_t& sb, int block_num);
void build_transaction_id_bins(const pqxx::result::const_iterator& transaction, std::vector<hive::protocol::transaction_id_type>& transaction_id_bins);
hive::protocol::signed_transaction build_transaction_bin(const pqxx::result::const_iterator& transaction, std::vector<hive::protocol::signature_type> signatures, std::vector<hive::protocol::operation> operation_bins);
void add_operation_bin(const pqxx::const_result_iterator& operation, std::vector<hive::protocol::operation>& operation_bins);
std::vector<hive::protocol::signature_type> build_signatures(const pqxx::result::const_iterator& transaction);
bool operation_matches_block_transaction(const pqxx::const_result_iterator& operation, int block_num, int trx_in_block);



// value coming from pxx is without 'T' in the middle to be accepted in variant
std::string fix_pxx_time(const pqxx::field& t);

// value coming from pxx is "\xABCDEFGHIJK", we need to cut 2 charaters from the front to be accepted in variant
const char* fix_pxx_hex(const pqxx::field& h);


csp_session_ptr_type csp_init_impl(const char* context, const char* shared_memory_bin_path, const char* postgres_url)
{

  try
  {
    // Dynamically allocate csp_session_type. Ownership transfers to SQL hive.session
    auto csp_session_ptr = new csp_session_type(context, shared_memory_bin_path, postgres_url);

    initialize_chain_db(*csp_session_ptr);

    return csp_session_ptr;
  }
  catch(...)
  {
    auto current_exception = std::current_exception();
    handle_exception(current_exception);
  }

  return 0;

}

void initialize_chain_db(csp_session_ref_type csp_session)
{

  hive::chain::database& db = *csp_session.db;

  db.set_flush_interval(10'000);
  db.set_require_locking(false);

  open_args db_open_args;

  set_open_args_data_dir(db_open_args, csp_session.shared_memory_bin_path);
  set_open_args_other_parameters(db_open_args);

  db.open(db_open_args);
};

void set_open_args_data_dir(open_args& db_open_args, const std::string&  shared_memory_bin_path)
{
  db_open_args.data_dir = shared_memory_bin_path;
  db_open_args.shared_mem_dir = db_open_args.data_dir / "blockchain";
};

void set_open_args_other_parameters(open_args& db_open_args)
{
  db_open_args.shared_file_size = CSP_SHARED_MEMORY_SIZE;
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


void csp_finish_impl(csp_session_ref_type csp_session, bool wipe_clean_shared_memory_bin)
{
  try
  {

    hive::chain::database& db = *csp_session.db.get();

    db.close();

    if(wipe_clean_shared_memory_bin)
    {
      db.chainbase::database::wipe(fc::path(csp_session.shared_memory_bin_path) / "blockchain");

      // Use std::cout like in database::wipe
      std::string log("Removing also:\n- " + csp_session.shared_memory_bin_path + "\n");
      std::cout << log;
      boost::filesystem::remove_all( fc::path(csp_session.shared_memory_bin_path));
    }

    delete &csp_session;
  }
  catch(...)
  {
    auto current_exception = std::current_exception();
    handle_exception(current_exception);
  }

}


int consensus_state_provider_get_expected_block_num_impl(csp_session_ref_type csp_session)
{
  return csp_session.db->head_block_num() + 1;
}


collected_account_balances_collection_t collect_current_all_accounts_balances_impl(csp_session_ref_type csp_session)
{
  return collect_current_all_accounts_balances(csp_session);
}


collected_account_balances_collection_t collect_current_account_balances_impl(csp_session_ref_type csp_session, const std::vector<std::string>& accounts)
{
  return collect_current_account_balances(csp_session, accounts);
}


bool consensus_state_provider_replay_impl(csp_session_ref_type csp_session, int first_block, int last_block)
{
  try
  {

    auto csp_expected_block = consensus_state_provider_get_expected_block_num_impl(csp_session);

    if(first_block < csp_expected_block)
    {
      undo_blocks(csp_session, csp_expected_block - first_block);
      csp_expected_block = consensus_state_provider_get_expected_block_num_impl(csp_session);
    }
    else
    {
      first_block = csp_expected_block;
    }

    FC_ASSERT(first_block == csp_expected_block,
      "ERROR: Cannot replay consensus state provider: Initial \"first_block\" block number is ${first_block}, but current state is expecting ${curr}",
      ("first_block", first_block)("curr", csp_expected_block));

    postgres_block_log(csp_session).run(first_block, last_block);
    return true;
  }
  catch(...)
  {
    auto current_exception = std::current_exception();
    handle_exception(current_exception);
  }

  return false;
}

void undo_blocks(csp_session_ref_type csp_session, int shift)
{
  auto& db = *csp_session.db;
  while(shift > 0)
  {
    db.pop_block();
    shift--;
  }
}

void postgres_block_log::run(int first_block, int last_block)
{
  measure_before_run();

  prepare_postgres_data(first_block, last_block);
  replay_blocks();

  measure_after_run();
}

full_block_ptr postgres_block_log::read_full_block(int block_num)
{

  prepare_postgres_data(block_num, block_num);
  return block_to_fullblock(block_num, blocks[0]);

}

// We get blocks, transactions and operations containers from SQL
// and set up iterators to transaction and operation
// so that the iterators always point to the transactions and operations belonging to the currently replayed block
void postgres_block_log::prepare_postgres_data(int first_block, int last_block)
{
  read_postgres_data(first_block, last_block);
  initialize_iterators();
}


void postgres_block_log::read_postgres_data(int first_block, int last_block)
{
  time_probe get_data_from_postgres_time_probe; get_data_from_postgres_time_probe.start();

  auto& conn = *(csp_session.conn);

  // clang-format off
    auto blocks_query = "SELECT * FROM hive.blocks_view JOIN hive.accounts_view ON  id = producer_account_id WHERE num >= "
                                + std::to_string(first_block)
                                + " and num <= "
                                + std::to_string(last_block)
                                + " ORDER BY num ASC";
    blocks = conn.execute_query(blocks_query);
    //std::cout << "Blocks:" << blocks.size() << " ";

    auto transactions_query = "SELECT block_num, trx_in_block, ref_block_num, ref_block_prefix, expiration, trx_hash, signature FROM hive.transactions_view WHERE block_num >= "
                                + std::to_string(first_block)
                                + " and block_num <= "
                                + std::to_string(last_block)
                                + " ORDER BY block_num, trx_in_block ASC";
    transactions = conn.execute_query(transactions_query);
    //std::cout << "Transactions:" << transactions.size() << " ";

    auto operations_query = "SELECT block_num, body_binary as bin_body, trx_in_block FROM hive.operations_view WHERE block_num >= "
                                + std::to_string(first_block)
                                + " and block_num <= "
                                + std::to_string(last_block)
                                + " AND op_type_id <= 49 " //trx_in_block < 0 -> virtual operation
                                + " ORDER BY id ASC";
  operations = conn.execute_query(operations_query);
  //std::cout << "Operations:" << operations.size() << " ";

  // clang-format on
  get_data_from_postgres_time_probe.stop(); get_data_from_postgres_time_probe.print_duration("Postgres");
}


void postgres_block_log::initialize_iterators()
{
  current_transaction = transactions.begin();
  current_operation = operations.begin();
}

void postgres_block_log::replay_blocks()
{
  for(const auto& block : blocks)
  {
    replay_block(block);
  }
}


void postgres_block_log::replay_block(const pqxx::row& block)
{
  transformations_time_probe.start();

  auto full_block = block_to_fullblock(consensus_state_provider_get_expected_block_num_impl(csp_session) , block);

  FC_ASSERT(full_block, "No full block to process");

  transformations_time_probe.stop();

  replay_full_block(*csp_session.db, full_block, get_skip_flags());

}

full_block_ptr postgres_block_log::block_to_fullblock(int block_num_from_shared_memory_bin, const pqxx::row& block)
{
  auto block_num_from_postgres = block["num"].as<int>();

  FC_ASSERT(block_num_from_postgres == block_num_from_shared_memory_bin, "Requested block has different number than the block in the state database");

  block_bin_t signed_block_object = postgres_block_log::block_to_bin(block);
  auto full_block = from_bin_to_full_block_ptr(signed_block_object, block_num_from_postgres);

  return full_block;
}


void postgres_block_log::replay_full_block(haf_state_database& db, const full_block_ptr& fb_ptr, uint64_t skip_flags)
{
  replay_full_block_time_probe.start();

  db.push_haf_block(fb_ptr, skip_flags);

  replay_full_block_time_probe.stop();
}


void haf_state_database::push_haf_block(const full_block_ptr& full_block, uint32_t skip)
{
  try
  {
    _node_property_object.skip_flags = skip;
    hive::chain::existing_block_flow_control flow_control(full_block);
    push_block(flow_control, skip);

  }FC_CAPTURE_AND_RETHROW()
}


void haf_state_database::state_dependent_open( const open_args& args )
{
  load_state_initial_data(args,
    [this](int block_num)
    {
      auto full_block = postgres_block_log(csp_session).read_full_block(head_block_num());
      return full_block;
    });
}




void postgres_block_log::measure_before_run()
{
  transformations_time_probe.reset();
  replay_full_block_time_probe.reset();
}

void postgres_block_log::measure_after_run()
{
  transformations_time_probe.print_duration("Transformations");
  replay_full_block_time_probe.print_duration("Transactional_apply_block");
}

void handle_exception(std::exception_ptr exception_ptr)
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



block_bin_t build_block_bin(const pqxx::row& block, std::vector<hive::protocol::transaction_id_type> transaction_id_bins, std::vector<hive::protocol::signed_transaction> transaction_bins)
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
  for(; current_transaction != transactions.end() && current_transaction_belongs_to_block(block_num); ++current_transaction)
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

bool postgres_block_log::current_transaction_belongs_to_block(const int block_num)
{
  return current_transaction["block_num"].as<int>() == block_num;
}

std::vector<hive::protocol::signature_type> build_signatures(const pqxx::result::const_iterator& transaction)
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

void build_transaction_id_bins(const pqxx::result::const_iterator& transaction,
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



hive::protocol::signed_transaction build_transaction_bin(const pqxx::result::const_iterator& transaction, std::vector<hive::protocol::signature_type> signatures, std::vector<hive::protocol::operation> operation_bins)
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

bool operation_matches_block_transaction(const pqxx::const_result_iterator& operation, int block_num, int trx_in_block)
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


void add_operation_bin(const pqxx::const_result_iterator& operation, std::vector<hive::protocol::operation>& operation_bins)
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


uint64_t get_skip_flags()
{
  using flags = hive::chain::database::validation_steps;

  return flags::skip_block_log |
         flags::skip_witness_signature |
         flags::skip_transaction_signatures |
         flags::skip_transaction_dupe_check |
         flags::skip_tapos_check |
         flags::skip_merkle_check |
         flags::skip_witness_schedule_check |
         flags::skip_authority_check |
         flags::skip_validate;
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


full_block_ptr from_bin_to_full_block_ptr(block_bin_t& sb, int block_num)
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
  return full_block_type::create_from_signed_block(sb);
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

collected_account_balances_collection_t collect_current_account_balances(csp_session_ref_type csp_session,
                                                                         const std::vector<std::string>& account_names)
{
  auto& db = *csp_session.db;

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

collected_account_balances_collection_t collect_current_all_accounts_balances(csp_session_ref_type csp_session)
{

  auto& db = *csp_session.db;

  collected_account_balances_collection_t collected_balances;

  auto& idx = db.get_index< hive::chain::account_index, hive::chain::by_name >();
  auto itr = idx.lower_bound( "" );

  auto end = idx.end();

  while( itr != end )
  {
    collected_balances.emplace_back(extract_account_balances(&(*itr)));
    ++itr;
  }
  return collected_balances;
}
}  // namespace consensus_state_provider
