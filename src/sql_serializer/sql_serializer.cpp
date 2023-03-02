#include <hive/plugins/sql_serializer/sql_serializer_plugin.hpp>

#include <hive/plugins/sql_serializer/cached_data.h>
#include <hive/plugins/sql_serializer/indexation_state.hpp>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>
#include <hive/plugins/sql_serializer/accounts_collector.h>

#include <hive/plugins/sql_serializer/data_processor.hpp>

#include <hive/plugins/sql_serializer/sql_serializer_objects.hpp>

#include <hive/chain/util/impacted.hpp>
#include <hive/chain/util/supplement_operations.hpp>
#include <hive/chain/index.hpp>

#include <hive/protocol/config.hpp>
#include <hive/protocol/operations.hpp>

#include <hive/utilities/plugin_utilities.hpp>
#include <hive/plugins/sql_serializer/blockchain_data_filter.hpp>

#include <fc/git_revision.hpp>
#include <fc/io/json.hpp>
#include <fc/io/sstream.hpp>
#include <fc/crypto/hex.hpp>
#include <fc/utf8.hpp>

#include <boost/filesystem.hpp>

#include <condition_variable>
#include <map>
#include <sstream>
#include <string>
#include <vector>



namespace hive
{
using chain::block_notification;
using chain::operation_notification;
using chain::reindex_notification;

namespace plugins
{
namespace sql_serializer
{
bool is_database_correct( const std::string& database_url, bool force_open_inconsistant )
{
  ilog( "Checking correctness of database..." );

  bool is_extension_created = false;
  bool is_irreversible_dirty = false;
  queries_commit_data_processor db_checker(
    database_url
    , "Check correctness"
    , [&is_extension_created](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
      pqxx::result data = tx.exec("select 1 as _result from pg_extension where extname='hive_fork_manager';");
      is_extension_created = !data.empty();
      return data_processor::data_processing_status();
      }
      , nullptr
      );

  db_checker.trigger(data_processor::data_chunk_ptr(), 0);
  db_checker.join();

  if ( !is_extension_created ) {
    elog( "The exstenion 'hive_fork_manager' is not created" );
    return false;
  }

  queries_commit_data_processor db_consistency_checker(
    database_url
    , "Check consistency of irreversible data"
    , [&is_irreversible_dirty](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
      
      // these tables need to be empty in haf extension script because of pg_dump/pg/restore
      tx.exec("INSERT INTO hive.irreversible_data VALUES(1,NULL, FALSE) ON CONFLICT DO NOTHING;");
      tx.exec("INSERT INTO hive.events_queue VALUES( 0, 'NEW_IRREVERSIBLE', 0 ) ON CONFLICT DO NOTHING;");
      tx.exec("INSERT INTO hive.fork(block_num, time_of_fork) VALUES( 1, '2016-03-24 16:05:00'::timestamp ) ON CONFLICT DO NOTHING;");
      tx.exec("SELECT hive.create_database_hash('hive');");

  
      pqxx::result data = tx.exec("select hive.is_irreversible_dirty() as _result;");
      FC_ASSERT( !data.empty(), "No response from database" );
      FC_ASSERT( data.size() == 1, "Wrong data size" );
      const auto& record = data[0];
      is_irreversible_dirty = record[ "_result" ].as<bool>();
      return data_processor::data_processing_status();
      }
      , nullptr
      );

  db_consistency_checker.trigger(data_processor::data_chunk_ptr(), 0);
  db_consistency_checker.join();

  if ( !is_irreversible_dirty ) {
    return true;
  }

  wlog( "The irreversible data are in inconsistent state" );

  if ( !force_open_inconsistant ) {
    elog( "Cannot open database because irreversible data are inconsistent. Removing inconsistancy may last long time, please use 'psql-force-open-inconsistent' switch to force open." );
    return false;
  }

  wlog( "Switch 'psql-force-open-inconsistent' was used, inconsistent database will be rapaired what may last long time" );
  return true;
}

inline std::string get_operation_name(const hive::protocol::operation& op)
{
  PSQL::name_gathering_visitor v;
  return op.visit(v);
}

using num_t = std::atomic<uint64_t>;
using duration_t = fc::microseconds;
using stat_time_t = std::atomic<duration_t>;

struct stat_t
{
  stat_time_t processing_time{ duration_t{0} };
  num_t count{0};
};

struct ext_stat_t : public stat_t
{
  stat_time_t flush_time{ duration_t{0} };

  void reset()
  {
    processing_time.store( duration_t{0} );
    flush_time.store( duration_t{0} );
    count.store(0);
  }
};

struct stats_group
{
  stat_time_t sending_cache_time{ duration_t{0} };
  uint64_t workers_count{0};
  uint64_t all_created_workers{0};

  ext_stat_t blocks{};
  ext_stat_t transactions{};
  ext_stat_t operations{};

  void reset()
  {
    blocks.reset();
    transactions.reset();
    operations.reset();

    sending_cache_time.store(duration_t{0});
    workers_count = 0;
    all_created_workers = 0;
  }
};

inline std::ostream& operator<<(std::ostream& os, const stat_t& obj)
{
  return os << obj.processing_time.load().count() << " us | count: " << obj.count.load();
}

inline std::ostream& operator<<(std::ostream& os, const ext_stat_t& obj)
{
  return os << "flush time: " << obj.flush_time.load().count() << " us | processing time: " << obj.processing_time.load().count() << " us | count: " << obj.count.load();
}

inline std::ostream& operator<<(std::ostream& os, const stats_group& obj)
{
  #define __shortcut( name ) << #name ": " << obj.name << std::endl
  return os
    << "threads created since last info: " << obj.all_created_workers << std::endl
    << "currently working threads: " << obj.workers_count << std::endl
    __shortcut(blocks)
    __shortcut(transactions)
    __shortcut(operations)
    ;
}

using namespace hive::plugins::sql_serializer::PSQL;

constexpr size_t default_reservation_size{ 16'000u };

namespace detail
{

using data_processing_status = data_processor::data_processing_status;
using data_chunk_ptr = data_processor::data_chunk_ptr;

class sql_serializer_plugin_impl final
{
public:

  sql_serializer_plugin_impl(
      const std::string &url
    , hive::chain::database& _chain_db
    , const sql_serializer_plugin& _main_plugin
    , uint32_t _psql_operations_threads_number
    , uint32_t _psql_transactions_threads_number
    , uint32_t _psql_account_operations_threads_number
    , uint32_t _psql_index_threshold
    , uint32_t _psql_livesync_threshold
    , bool     _psql_enable_filter
  )
  : _indexation_state( _main_plugin, _chain_db, url,
                          _psql_transactions_threads_number,
                          _psql_operations_threads_number,
                          _psql_account_operations_threads_number,
                          _psql_index_threshold,
                          _psql_livesync_threshold
                          ),
      db_url{url},
      chain_db{_chain_db},
      main_plugin{_main_plugin},
      psql_transactions_threads_number( _psql_transactions_threads_number ),
      psql_operations_threads_number( _psql_operations_threads_number ),
      psql_account_operations_threads_number( _psql_account_operations_threads_number ),
      filter( _psql_enable_filter, op_extractor )
  {
    HIVE_ADD_PLUGIN_INDEX(chain_db, account_ops_seq_index);
  }

  ~sql_serializer_plugin_impl()
  {
    ilog("Serializer plugin is closing");
  }

  void connect_signals();
  void disconnect_signals();

  void on_pre_reindex(const reindex_notification& note);
  void on_post_reindex(const reindex_notification& note);
  void on_end_of_syncing();

  void on_pre_apply_operation(const operation_notification& note);
  void on_pre_apply_block(const block_notification& note);
  void on_post_apply_block(const block_notification& note);

  void unblock_operation_handlers(const block_notification& note);
  void block_operation_handlers(const block_notification& note);

  void handle_transactions(const vector<std::shared_ptr<hive::chain::full_transaction_type>>& transactions, const int64_t block_num);
  void inform_hfm_about_starting();
  void collect_account_operations(int64_t operation_id, const hive::protocol::operation& op, uint32_t block_num);

  boost::signals2::connection _on_pre_apply_operation_con;
  std::unique_ptr< boost::signals2::shared_connection_block > _pre_apply_operation_blocker;
  boost::signals2::connection __on_pre_apply_block_con_initialization;
  boost::signals2::connection _on_pre_apply_block_con_unblock_operations;
  boost::signals2::connection _on_post_apply_block_con_block_operations;
  boost::signals2::connection _on_starting_reindex;
  boost::signals2::connection _on_finished_reindex;
  boost::signals2::connection _on_end_of_syncing_con;
  boost::signals2::connection _on_switch_fork_conn;
  indexation_state _indexation_state;

  std::string db_url;
  hive::chain::database& chain_db;
  const sql_serializer_plugin& main_plugin;

  uint32_t _last_block_num = 0;

  uint32_t last_skipped_block = 0;
  uint32_t psql_block_number = 0;
  uint32_t psql_index_threshold = 0;
  uint32_t psql_transactions_threads_number = 2;
  uint32_t psql_operations_threads_number = 5;
  uint32_t psql_account_operations_threads_number = 2;
  bool     psql_dump_account_operations = true;
  uint32_t head_block_number = 0;

  int64_t op_sequence_id = 0;

  cached_containter_t currently_caching_data;
  std::unique_ptr<accounts_collector> collector;
  stats_group current_stats;
  type_extractor::operation_extractor op_extractor;
  blockchain_filter filter;

  void log_statistics()
  {
    std::cout << current_stats;
    current_stats.reset();
  }

  auto get_switch_indexes_function( const std::string& query, bool mode, const std::string& objects_name ) {
    auto function = [query, &objects_name, mode](const data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processing_status
      {
        ilog("Attempting to execute query: `${query}`...", ("query", query ) );
        const auto start_time = fc::time_point::now();
        tx.exec( query );
        ilog(
          "${mode} of ${mod_type} done in ${time} ms",
          ("mode", (mode ? "Creating" : "Saving and dropping")) ("mod_type", objects_name) ("time", (fc::time_point::now() - start_time).count() / 1000.0 )
          );
        return data_processing_status();
      };

      return function;
  }

  void init_database(bool freshDb, uint32_t max_block_number )
  {
    head_block_number = max_block_number;

    load_initial_db_data();
    if(freshDb)
    {
      auto get_type_definitions = [ this ](const data_processor::data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx){
        auto types = PSQL::get_all_type_definitions( op_extractor );
        if ( types.empty() )
          return data_processing_status();;

        tx.exec( types );
        return data_processing_status();
      };
      queries_commit_data_processor processor( db_url, "Get type definitions", get_type_definitions, nullptr );
      processor.trigger( nullptr, 0 );
      processor.join();
    }
  }

  void inform_hfm_about_starting(hive::chain::database& _chaindb) {
    using namespace std::string_literals;
    ilog( "Inform Hive Fork Manager about starting..." );

    // inform the db about starting hivd
    auto connect_to_the_db = [&_chaindb](const data_processor::data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx){
      const auto CONNECT_QUERY = "SELECT hive.connect("s + fc::git_revision_sha + ","s + std::to_string( _chaindb.head_block_num() ) + ")"s;
      tx.exec( CONNECT_QUERY );
      return data_processing_status();
    };
    queries_commit_data_processor processor( db_url, "Connect to the db", connect_to_the_db, nullptr );
    processor.trigger( nullptr, 0 );
    processor.join();
  }

  void load_initial_db_data()
  {
    ilog("Loading operation's last id ...");

    op_sequence_id = 0;
    psql_block_number = 0;

    queries_commit_data_processor block_loader(db_url, "Block loader",
                                                [this](const data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processing_status
      {
        pqxx::result data = tx.exec("SELECT hb.num AS _max_block FROM hive.blocks hb ORDER BY hb.num DESC LIMIT 1;");
        if( !data.empty() )
        {
          FC_ASSERT( data.size() == 1, "Data size" );
          const auto& record = data[0];
          psql_block_number = record["_max_block"].as<uint64_t>();
          _last_block_num = psql_block_number;
        }
        return data_processing_status();
      }
      , nullptr
    );

    block_loader.trigger(data_processor::data_chunk_ptr(), 0);

    queries_commit_data_processor sequence_loader(db_url, "Sequence loader",
                                                  [this](const data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processing_status
      {
        pqxx::result data = tx.exec("SELECT ho.id AS _max FROM hive.operations ho ORDER BY ho.id DESC LIMIT 1;");
        if( !data.empty() )
        {
          FC_ASSERT( data.size() == 1, "Data size 2" );
          const auto& record = data[0];
          op_sequence_id = record["_max"].as<int64_t>();
          //because newly created operation has to have subsequent number
          ++op_sequence_id;
        }
        return data_processing_status();
      }
      , nullptr
    );

    sequence_loader.trigger(data_processor::data_chunk_ptr(), 0);

    sequence_loader.join();
    block_loader.join();

    ilog("Next operation id: ${s} psql block number: ${pbn}.",
      ("s", op_sequence_id)("pbn", psql_block_number));
  }

  bool skip_reversible_block(uint32_t block);
};

void sql_serializer_plugin_impl::inform_hfm_about_starting() {
  using namespace std::string_literals;
  ilog( "Inform Hive Fork Manager about starting..." );

  // inform the db about starting hivd
  auto connect_to_the_db = [&](const data_processor::data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx){
    const auto CONNECT_QUERY = "SELECT hive.connect('"s + fc::git_revision_sha + "',"s + std::to_string( chain_db.head_block_num() ) + "::INTEGER);"s;
    tx.exec( CONNECT_QUERY );
    return data_processing_status();
  };
  queries_commit_data_processor processor( db_url, "Connect to the db", connect_to_the_db, nullptr );
  processor.trigger( nullptr, 0 );
  processor.join();
}

void sql_serializer_plugin_impl::connect_signals()
{
  _on_pre_apply_operation_con = chain_db.add_pre_apply_operation_handler([&](const operation_notification& note) { on_pre_apply_operation(note); }, main_plugin);
  _pre_apply_operation_blocker = std::make_unique< boost::signals2::shared_connection_block >( _on_pre_apply_operation_con );

  __on_pre_apply_block_con_initialization = chain_db.add_pre_apply_block_handler([&](const block_notification& note) { on_pre_apply_block(note); }, main_plugin);
  _on_finished_reindex = chain_db.add_post_reindex_handler([&](const reindex_notification& note) { on_post_reindex(note); }, main_plugin);
  _on_starting_reindex = chain_db.add_pre_reindex_handler([&](const reindex_notification& note) { on_pre_reindex(note); }, main_plugin);
  _on_end_of_syncing_con = chain_db.add_end_of_syncing_handler([&]() { on_end_of_syncing(); }, main_plugin);
  _on_switch_fork_conn = chain_db.add_switch_fork_handler(
    [&]( uint32_t block_num ){ _indexation_state.on_switch_fork( *currently_caching_data, block_num ); }, main_plugin );

  _on_pre_apply_block_con_unblock_operations = chain_db.add_pre_apply_block_handler([&](const block_notification& note) { unblock_operation_handlers(note); }, main_plugin);
  _on_post_apply_block_con_block_operations = chain_db.add_post_apply_block_handler([&](const block_notification& note) { block_operation_handlers(note); }, main_plugin);
}

void sql_serializer_plugin_impl::disconnect_signals()
{
  if(__on_pre_apply_block_con_initialization.connected())
    chain::util::disconnect_signal(__on_pre_apply_block_con_initialization);
  if(_on_pre_apply_operation_con.connected())
    chain::util::disconnect_signal(_on_pre_apply_operation_con);
  if(_on_starting_reindex.connected())
    chain::util::disconnect_signal(_on_starting_reindex);
  if(_on_finished_reindex.connected())
    chain::util::disconnect_signal(_on_finished_reindex);
  if ( _on_end_of_syncing_con.connected() )
    chain::util::disconnect_signal(_on_end_of_syncing_con);
  if ( _on_switch_fork_conn.connected() )
    chain::util::disconnect_signal(_on_switch_fork_conn);
  if ( _on_pre_apply_operation_con.connected() )
    chain::util::disconnect_signal(_on_pre_apply_operation_con);
}

void sql_serializer_plugin_impl::on_pre_apply_block(const block_notification& note)
{
  ilog("Entering a resync data init for block: ${b}...", ("b", note.block_num));

  /// Let's init our database before applying first block (resync case)...
  inform_hfm_about_starting();
  init_database(note.block_num == 1, note.block_num);
  _indexation_state.on_first_block();

  /// And disconnect to avoid subsequent inits
  if(__on_pre_apply_block_con_initialization.connected())
    chain::util::disconnect_signal(__on_pre_apply_block_con_initialization);
  ilog("Leaving a resync data init...");
}


struct hardfork_id_extractor_visitor
{
  typedef void result_type;

  int hardfork_id;
  template<typename T>
  void operator()( const T& op )
    {
      hardfork_id = -1;
    }

  void operator()( const hive::protocol::hardfork_operation& op )
    {
      hardfork_id = op.hardfork_id;
    }
};

int get_hardfork_id(const hive::protocol::operation& op)
{
  hardfork_id_extractor_visitor vis;
  op.visit(vis);
  return vis.hardfork_id;
}

void sql_serializer_plugin_impl::on_pre_apply_operation(const operation_notification& note)
{
  FC_ASSERT((chain_db.is_processing_block() && chain_db.is_producing_block()==false), "SQL serializer shall process only operations contained by finished blocks");

  if(!is_effective_operation(note.op))
    return;

  if(skip_reversible_block(note.block))
    return;

  hive::util::supplement_operation(note.op, chain_db);

  const bool is_virtual = hive::protocol::is_virtual_operation(note.op);
  FC_ASSERT( is_virtual || note.trx_in_block >= 0,  "Non is_producing real operation with trx_in_block = -1" );

  collect_account_operations( op_sequence_id, note.op, note.block );

  if( collector->is_op_accepted() )
  {
    filter.remember_trx_id( note.trx_in_block );

    cached_containter_t& cdtf = currently_caching_data; // alias

   int hardfork_num = get_hardfork_id(note.op);
    if(hardfork_num > 0)
    {
      cdtf->applied_hardforks.emplace_back(
        hardfork_num,
        note.block,
        op_sequence_id
      );
    }

    cdtf->operations.emplace_back(
      op_sequence_id,
      note.block,
      note.trx_in_block,
      note.op_in_trx,
      chain_db.head_block_time(),
      note.op
    );
  }
  ++op_sequence_id;
}

void sql_serializer_plugin_impl::on_post_apply_block(const block_notification& note)
{
  if(skip_reversible_block(note.block_num))
    return;

  handle_transactions(note.full_block->get_full_transactions(), note.block_num);

  const hive::chain::signed_block_header& block_header = note.full_block->get_block_header();
  const hive::chain::account_object* account_ptr = chain_db.find_account(block_header.witness);
  const hive::chain::witness_object* witness_ptr = chain_db.find_witness(block_header.witness);

  const hive::chain::dynamic_global_property_object& dgpo = chain_db.get_dynamic_global_properties();

  currently_caching_data->total_size += note.block_id.data_size() + sizeof(note.block_num);
  currently_caching_data->blocks.emplace_back(
    note.block_id,
    note.block_num,
    block_header.timestamp,
    note.prev_block_id,
    account_ptr->get_id(),
    block_header.transaction_merkle_root,
    (block_header.extensions.size() == 0) ? fc::optional<std::string>() : fc::optional<std::string>(fc::json::to_string( block_header.extensions )),
    block_header.witness_signature,
    witness_ptr->signing_key,
    
    dgpo.hbd_interest_rate,

    dgpo.total_vesting_shares,
    dgpo.total_vesting_fund_hive,

    dgpo.total_reward_fund_hive,

    dgpo.virtual_supply,
    dgpo.current_supply,

    dgpo.current_hbd_supply,
    dgpo.init_hbd_supply
    );

  _last_block_num = note.block_num;

  _indexation_state.trigger_data_flush( *currently_caching_data, _last_block_num );

  filter.clear();

  if(note.block_num % 100'000 == 0)
  {
    log_statistics();
  }
}

void sql_serializer_plugin_impl::unblock_operation_handlers(const block_notification& note)
{
  _pre_apply_operation_blocker->unblock();
}

void sql_serializer_plugin_impl::block_operation_handlers(const block_notification& note)
{
  /// Do the same as usually
  on_post_apply_block(note);

  /// block operations signals
  _pre_apply_operation_blocker->block();
}

void sql_serializer_plugin_impl::handle_transactions(const vector<std::shared_ptr<hive::chain::full_transaction_type>>& transactions, const int64_t block_num)
{
  int64_t trx_in_block = 0;

  for(auto& trx : transactions)
  {
    if( !filter.is_trx_accepted( trx_in_block ) )
    {
      ++trx_in_block;
      continue;
    }

    auto hash = trx->get_transaction_id();
    const hive::protocol::signed_transaction& signed_trx = trx->get_transaction();
    size_t sig_size = signed_trx.signatures.size();

    currently_caching_data->total_size += sizeof(hash) + sizeof(block_num) + sizeof(trx_in_block) +
      sizeof(signed_trx.ref_block_num) + sizeof(signed_trx.ref_block_prefix) + sizeof(signed_trx.expiration) + sizeof(signed_trx.signatures[0]);

    currently_caching_data->transactions.emplace_back(
      hash,
      block_num,
      trx_in_block,
      signed_trx.ref_block_num,
      signed_trx.ref_block_prefix,
      signed_trx.expiration,
      (sig_size == 0) ? fc::optional<signature_type>() : fc::optional<signature_type>(signed_trx.signatures[0])
    );

    if(sig_size > 1)
    {
      auto itr = signed_trx.signatures.begin() + 1;
      while(itr != signed_trx.signatures.end())
      {
        currently_caching_data->transactions_multisig.emplace_back(
          hash,
          block_num,
          *itr
        );
        ++itr;
      }
    }

    trx_in_block++;
  }
}

void sql_serializer_plugin_impl::on_pre_reindex(const reindex_notification& note)
{
  ilog("Entering a reindex init...");
  /// Let's init our database before applying first block...
  inform_hfm_about_starting();
  init_database(note.force_replay, note.max_block_number);

  /// Disconnect pre-apply-block handler to avoid another initialization (for resync case).
  if(__on_pre_apply_block_con_initialization.connected())
    chain::util::disconnect_signal(__on_pre_apply_block_con_initialization);

  if ( note.args.stop_replay_at ) {
    _indexation_state.on_pre_reindex( *currently_caching_data, _last_block_num, ( note.args.stop_replay_at - _last_block_num ) );
  } else {
    _indexation_state.on_pre_reindex( *currently_caching_data, _last_block_num, 0 );
  }
  ilog("Leaving a reindex init...");
}

void sql_serializer_plugin_impl::on_post_reindex(const reindex_notification& note)
{
  ilog("finishing from post reindex");

  _indexation_state.on_post_reindex( *currently_caching_data, _last_block_num, note.args.stop_replay_at );
}

void sql_serializer_plugin_impl::on_end_of_syncing()
{
  /** Disconnect pre-apply-block/post-apply block handlers to enable runtime installation of pre/post aplly operation signals.
  *   This way all operations being processed by "external" transactions (not included in block) will be silently ignored, without any need to special filtering.
  */

  _indexation_state.on_end_of_syncing( *currently_caching_data, _last_block_num );
}

bool sql_serializer_plugin_impl::skip_reversible_block(uint32_t block_no)
{
  if(block_no <= psql_block_number)
  {
    FC_ASSERT(block_no > chain_db.get_last_irreversible_block_num(), "Block irreversible");

    if( last_skipped_block == 0 )
      last_skipped_block = block_no;
    if(block_no >= last_skipped_block + 1000)
    {
      ilog("Skipping data provided by already processed reversible block: ${block_no}", ("block_no", block_no));
      last_skipped_block = 0;
    }

    return true;
  }

  return false;
}

void sql_serializer_plugin_impl::collect_account_operations(
    int64_t operation_id
  , const hive::protocol::operation& op
  , uint32_t block_num
)
{
  collector->collect(operation_id, op, block_num);
}

} // namespace detail

sql_serializer_plugin::sql_serializer_plugin() {}
sql_serializer_plugin::~sql_serializer_plugin() {}


void sql_serializer_plugin::set_program_options(appbase::options_description &cli, appbase::options_description &cfg)
{
  cfg.add_options()("psql-url", boost::program_options::value<string>(), "postgres connection string")
                    ("psql-index-threshold", appbase::bpo::value<uint32_t>()->default_value( 1'000'000 ), "indexes/constraints will be recreated if `psql_block_number + psql_index_threshold >= head_block_number`")
                    ("psql-operations-threads-number", appbase::bpo::value<uint32_t>()->default_value( 5 ), "number of threads which dump operations to database during reindexing")
                    ("psql-transactions-threads-number", appbase::bpo::value<uint32_t>()->default_value( 2 ), "number of threads which dump transactions to database during reindexing")
                    ("psql-account-operations-threads-number", appbase::bpo::value<uint32_t>()->default_value( 2 ), "number of threads which dump account operations to database during reindexing")
                    ("psql-enable-account-operations-dump", appbase::bpo::value<bool>()->default_value( true ), "enable collect data to account_operations table")
                    ("psql-force-open-inconsistent", appbase::bpo::bool_switch()->default_value( false ), "force open database even when irreversible data are inconsistent")
                    ("psql-livesync-threshold", appbase::bpo::value<uint32_t>()->default_value( 100000 ), "threshold to move synchronization state during start immediatly to live")
                    ("psql-track-account-range", boost::program_options::value< std::vector<std::string> >()->composing()->multitoken(), "Defines a range of accounts to track as a json pair [\"from\",\"to\"] [from,to]. Can be specified multiple times.")
                    ("psql-track-operations", boost::program_options::value< std::vector<std::string> >()->composing(), "Defines operations' types to track. Can be specified multiple times.")
                    ("psql-track-body-operations", boost::program_options::value< std::vector<std::string> >()->composing()->multitoken(), "For a type of operation it's defined a regex that filters body of operation and decides if it's excluded. Can be specified multiple times. A complex regex can cause slowdown or processing can be even abandoned due to complexity.")
                    ("psql-enable-filter", appbase::bpo::value<bool>()->default_value( true ), "enable filtering accounts and operations")
                    ;
}

void sql_serializer_plugin::plugin_initialize(const boost::program_options::variables_map &options)
{
  ilog("Initializing sql serializer plugin");
  FC_ASSERT(options.count("psql-url"), "`psql-url` is required argument");

  auto& db = appbase::app().get_plugin<hive::plugins::chain::chain_plugin>().db();

  FC_ASSERT( is_database_correct( options["psql-url"].as<fc::string>(), options["psql-force-open-inconsistent"].as<bool>() )
              , "SQL database is in invalid state"
  );

  my = std::make_unique<detail::sql_serializer_plugin_impl>(
    options["psql-url"].as<fc::string>()
    , db
    , *this
    , options["psql-operations-threads-number"].as<uint32_t>()
    , options["psql-transactions-threads-number"].as<uint32_t>()
    , options["psql-account-operations-threads-number"].as<uint32_t>()
    , options["psql-index-threshold"].as<uint32_t>()
    , options["psql-livesync-threshold"].as<uint32_t>()
    , options["psql-enable-filter"].as<bool>()
  );

  // settings
  my->psql_index_threshold = options["psql-index-threshold"].as<uint32_t>();
  my->psql_dump_account_operations = options["psql-enable-account-operations-dump"].as<bool>();

  my->currently_caching_data = std::make_unique<cached_data_t>( default_reservation_size );

  my->filter.fill( options, "psql-track-account-range", "psql-track-operations", "psql-track-body-operations" );

  if( my->filter.is_enabled() )
    my->collector = std::make_unique<filtered_accounts_collector>( db, *my->currently_caching_data, my->psql_dump_account_operations, my->filter );
  else
    my->collector = std::make_unique<accounts_collector>( db, *my->currently_caching_data, my->psql_dump_account_operations );

  // signals
  my->connect_signals();
}

void sql_serializer_plugin::plugin_startup()
{
  ilog("sql::plugin_startup()");
}

void sql_serializer_plugin::plugin_shutdown()
{
  ilog("Flushing left data...");

  my->disconnect_signals();

  ilog("Done. Connection closed");
}

} // namespace sql_serializer
}    // namespace plugins
} // namespace hive
