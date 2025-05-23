#include <hive/plugins/sql_serializer/indexation_state.hpp>

#include <hive/plugins/sql_serializer/all_accounts_dumper.h>
#include <hive/plugins/sql_serializer/cached_data.h>
#include <hive/plugins/sql_serializer/sql_serializer_plugin.hpp>
#include <hive/plugins/sql_serializer/fake_data_dumper.h>
#include <hive/plugins/sql_serializer/livesync_data_dumper.h>
#include <hive/plugins/sql_serializer/reindex_data_dumper.h>
#include <hive/plugins/sql_serializer/all_accounts_dumper.h>

#include <fc/exception/exception.hpp>
#include <fc/log/logger.hpp>

#include <exception>
#include <type_traits>

namespace hive{ namespace plugins{ namespace sql_serializer {

template<typename block_element>
void move_items_upto_block( std::vector< block_element >& target, std::vector< block_element >& source, uint32_t block_number ) {
  static_assert( std::is_base_of< PSQL::processing_objects::block_data_base, block_element >::value, "Suports only items derived from PSQL::processing_objects::block_data_base" );
  auto blocks_cmp = []( const PSQL::processing_objects::block_data_base& block_base_first, const PSQL::processing_objects::block_data_base& block_base_second  )->bool{
    return block_base_first.block_number < block_base_second.block_number;
  };

  auto block_it
    = std::upper_bound( source.begin(), source.end(), block_number, blocks_cmp );

  target.insert( target.begin(), source.begin(), block_it );
  source.erase( source.begin(), block_it );
}

template<typename block_element>
void erase_items_greater_than_block( std::vector< block_element >& block_items, uint32_t block_number ) {
  static_assert( std::is_base_of< PSQL::processing_objects::block_data_base, block_element >::value, "Suports only items derived from PSQL::processing_objects::block_data_base" );
  auto blocks_cmp = []( const PSQL::processing_objects::block_data_base& block_base_first, const PSQL::processing_objects::block_data_base& block_base_second  )->bool{
    return block_base_first.block_number < block_base_second.block_number;
  };

  auto first_after_block_it
    = std::lower_bound( block_items.begin(), block_items.end(), block_number + 1, blocks_cmp );

  block_items.erase( first_after_block_it, block_items.end() );
}

cached_data_t move_irreveresible_blocks( cached_data_t& cached_data, uint32_t irreversible_block ) {
  cached_data_t irreversible_data{0};
  if ( irreversible_block == indexation_state::NO_IRREVERSIBLE_BLOCK ) {
    return irreversible_data;
  }

  move_items_upto_block( irreversible_data.blocks, cached_data.blocks, irreversible_block );
  move_items_upto_block( irreversible_data.transactions, cached_data.transactions, irreversible_block );
  move_items_upto_block( irreversible_data.transactions_multisig, cached_data.transactions_multisig, irreversible_block );
  move_items_upto_block( irreversible_data.operations, cached_data.operations, irreversible_block );
  move_items_upto_block( irreversible_data.accounts, cached_data.accounts, irreversible_block );
  move_items_upto_block( irreversible_data.account_operations, cached_data.account_operations, irreversible_block );
  move_items_upto_block( irreversible_data.applied_hardforks, cached_data.applied_hardforks, irreversible_block );

  return irreversible_data;
}

class indexation_state::flush_trigger {
public:
  virtual ~flush_trigger() = default;
  virtual void flush( cached_data_t& cached_data, int32_t last_block_num, int32_t irreversible_block_num ) = 0;
};

class fake_flush_trigger : public indexation_state::flush_trigger {
public:
  void flush( cached_data_t& cached_data, int32_t last_block_num, int32_t irreversible_block_num ) override {}
};

class reindex_flush_trigger : public indexation_state::flush_trigger {
public:
  using flush_data_callback = std::function< void(cached_data_t& cached_data, int) >;
  reindex_flush_trigger( flush_data_callback callback ) : _flush_data_callback( callback ) {}
  ~reindex_flush_trigger() override = default;
  void flush( cached_data_t& cached_data, int32_t last_block_num, int32_t irreversible_block_num ) override {
    constexpr auto BLOCKS_PER_FLUSH = 1000;
    if( last_block_num % BLOCKS_PER_FLUSH == 0 )
    {
      _flush_data_callback( cached_data, last_block_num );
    }
  }
private:
  flush_data_callback _flush_data_callback;
};

class live_flush_trigger : public indexation_state::flush_trigger {
public:
  using flush_data_callback = std::function< void(cached_data_t& cached_data, int) >;
  live_flush_trigger( flush_data_callback callback ) : _flush_data_callback( callback ) {}
  ~live_flush_trigger() override = default;
  void flush( cached_data_t& cached_data, int32_t last_block_num, int32_t irreversible_block_num ) override {
    _flush_data_callback( cached_data, last_block_num );
  }
private:
  flush_data_callback _flush_data_callback;
};

class p2p_flush_trigger : public indexation_state::flush_trigger {
public:
  using flush_data_callback = std::function< void(cached_data_t& cached_data, int) >;
  static constexpr auto MINIMUM_BLOCKS_PER_FLUSH = 1000;

  p2p_flush_trigger( const sql_serializer_plugin& plugin, hive::chain::database& chain_db, flush_data_callback callback )
    : _flush_data_callback( callback )
    , last_flushed_block_num( 0 )
  {
  }

  ~p2p_flush_trigger() override = default;

  void flush( cached_data_t& cached_data, int32_t last_block_num, int32_t irreversible_block_num ) override {
    if ( irreversible_block_num == indexation_state::NO_IRREVERSIBLE_BLOCK ) {
      return;
    }

    if ( (irreversible_block_num - last_flushed_block_num) < MINIMUM_BLOCKS_PER_FLUSH ) {
      return;
    }

    auto irreversible_data = move_irreveresible_blocks(cached_data, irreversible_block_num);
    _flush_data_callback( irreversible_data, irreversible_block_num );
    last_flushed_block_num = irreversible_block_num;
  }
private:
  flush_data_callback _flush_data_callback;
  boost::signals2::connection _on_irreversible_block_conn;

  int32_t last_flushed_block_num;
};


indexation_state::indexation_state(
    const sql_serializer_plugin& main_plugin
  , hive::chain::database& chain_db
  , std::string db_url
  , appbase::application& app
  , uint32_t psql_transactions_threads_number
  , uint32_t psql_operations_threads_number
  , uint32_t psql_account_operations_threads_number
  , uint32_t psql_index_threshold
  , uint32_t psql_livesync_threshold
  , uint32_t psql_first_block
  , write_ahead_log_manager& write_ahead_log
)
  : _main_plugin( main_plugin )
  , _chain_db( chain_db )
  , _db_url( db_url )
  , theApp( app )
  , _psql_transactions_threads_number( psql_transactions_threads_number )
  , _psql_operations_threads_number( psql_operations_threads_number )
  , _psql_account_operations_threads_number( psql_account_operations_threads_number )
  , _psql_livesync_threshold( psql_livesync_threshold )
  , _psql_first_block( psql_first_block )
  , _irreversible_block_num( NO_IRREVERSIBLE_BLOCK )
  , _indexes_controler( db_url, psql_index_threshold, app )
  , _write_ahead_log{write_ahead_log} 
{
  FC_ASSERT( _psql_first_block >= 1, "psql-first-block=${v} < 1", ("v", _psql_first_block) );
  cached_data_t empty_data{0};
  set_state( INDEXATION::START );
  ilog( "Entered START sync state" );
  _start_state_time = fc::time_point::now();

  _on_irreversible_block_conn = _chain_db.add_irreversible_block_handler(
      [this]( uint32_t block_num ){ on_irreversible_block( block_num ); }
    , _main_plugin
  );
}

void
indexation_state::on_pre_reindex( cached_data_t& cached_data, int last_block_num, uint32_t number_of_blocks_to_add ) {
  switch ( get_state() ) {
    case INDEXATION::P2P:
    case INDEXATION::LIVE:
    case INDEXATION::WAIT:
    case INDEXATION::REINDEX:
    case INDEXATION::REINDEX_WAIT:
    case INDEXATION::START:
      if ( can_move_to_livesync() ) {
        update_state( INDEXATION::WAIT, cached_data, 0 );
        return;
      }
      update_state( INDEXATION::REINDEX_WAIT, cached_data, last_block_num, number_of_blocks_to_add );
  }
}

void
indexation_state::on_post_reindex( cached_data_t& cached_data, uint32_t last_block_num, uint32_t _stop_replay_at ) {
  auto end_of_syncing = [this, _stop_replay_at, last_block_num, &cached_data]{
    if ( !_stop_replay_at )
      return false;

    if ( _stop_replay_at != last_block_num )
      return false;

    force_trigger_flush_with_all_data( cached_data, last_block_num );
    _trigger.reset();
    _dumper.reset();
    _indexes_controler.enable_indexes();
    _indexes_controler.enable_constrains();
    return true;
  };

  switch ( get_state() ) {
    case INDEXATION::START:
    case INDEXATION::P2P:
    case INDEXATION::LIVE:
    case INDEXATION::WAIT:
      return;
    case INDEXATION::REINDEX:
      if ( end_of_syncing() )
        return;

      update_state( INDEXATION::P2P, cached_data, last_block_num, UNKNOWN );
      return;
    case INDEXATION::REINDEX_WAIT:
      if ( end_of_syncing() )
        return;

      update_state( INDEXATION::WAIT, cached_data, last_block_num, UNKNOWN );
      return;
  }
}

void
indexation_state::on_end_of_syncing( cached_data_t& cached_data, int last_block_num ) {
  if ( get_state() == INDEXATION::LIVE ) {
    return;
  }

  update_state( INDEXATION::LIVE, cached_data, last_block_num, UNKNOWN );
}

void
indexation_state::on_first_block( int last_block_num ) {
  cached_data_t empty_cache{0};
  switch( get_state() ) {
    case INDEXATION::START:
    case INDEXATION::WAIT:
      if ( can_move_to_livesync() ) {
        update_state( INDEXATION::LIVE, empty_cache, last_block_num );
        return;
      }
      update_state( INDEXATION::P2P, empty_cache, last_block_num );
      return;
    case INDEXATION::REINDEX_WAIT:
      update_state( INDEXATION::REINDEX, empty_cache, last_block_num );
      return;
    case INDEXATION::REINDEX:
    case INDEXATION::P2P:
    case INDEXATION::LIVE:
      return;
  }
}

void
indexation_state::on_block( int last_block_num ) {
  switch( get_state() ) {
    case INDEXATION::START: {
      cached_data_t empty_cache{0};
      update_state( INDEXATION::WAIT, empty_cache, last_block_num );
      break;
      }
  }

  if ( last_block_num >= _psql_first_block ) {
    on_first_block( last_block_num );
  }
}

bool
indexation_state::can_move_to_livesync() const {
  return fc::time_point::now() - _chain_db.head_block_time() < fc::seconds( _psql_livesync_threshold * 3 );
}

uint32_t
indexation_state::expected_number_of_blocks_to_sync() const {
  return ( fc::time_point::now() - _chain_db.head_block_time() ).to_seconds() / 3;
}

void
indexation_state::update_state(
    INDEXATION state
  , cached_data_t& cached_data
  , uint32_t last_block_num, uint32_t number_of_blocks_to_add
) {
  FC_ASSERT( get_state() != INDEXATION::LIVE, "Move from LIVE state is illegal" );
  switch ( state ) {
    case INDEXATION::START:
      break;
    case INDEXATION::P2P:
      ilog("Entering P2P sync...");
      force_trigger_flush_with_all_data( cached_data, last_block_num );
      _trigger.reset();
      _dumper.reset();
      _indexes_controler.disable_constraints();
      _indexes_controler.disable_indexes_depends_on_blocks( expected_number_of_blocks_to_sync() );
      _dumper = std::make_shared< reindex_data_dumper >(
          _db_url
        , theApp
        , _psql_operations_threads_number
        , _psql_transactions_threads_number
        , _psql_account_operations_threads_number
      );
      _irreversible_block_num = NO_IRREVERSIBLE_BLOCK;
      _trigger = std::make_unique< p2p_flush_trigger >(
          _main_plugin
        , _chain_db
        , [this]( cached_data_t& cached_data, int last_block_num ) {
            force_trigger_flush_with_all_data( cached_data, last_block_num );
          }
      );
      ilog("PROFILE: Entered P2P sync from start state: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      break;
    case INDEXATION::REINDEX:
      ilog("PROFILE: Entering REINDEX sync from start state, dropping constraints: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      FC_ASSERT( get_state() == INDEXATION::START || get_state() == INDEXATION::REINDEX_WAIT , "Reindex always starts after START or REINDEX_WAIT" );

      force_trigger_flush_with_all_data( cached_data, last_block_num );
      _trigger.reset();
      _dumper.reset();
      _indexes_controler.disable_constraints();
      _indexes_controler.disable_indexes_depends_on_blocks(
        number_of_blocks_to_add == 0 // stop_replay_at_block = 0
        ? expected_number_of_blocks_to_sync()
        : number_of_blocks_to_add
      );
      _dumper = std::make_shared< reindex_data_dumper >(
          _db_url
        , theApp
        , _psql_operations_threads_number
        , _psql_transactions_threads_number
        , _psql_account_operations_threads_number
      );
      _trigger = std::make_unique< reindex_flush_trigger >(
        [this]( cached_data_t& cached_data, int last_block_num ) {
          force_trigger_flush_with_all_data( cached_data, last_block_num );
        }
      );
      ilog("PROFILE: Entered REINDEX sync from start state: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      break;
    case INDEXATION::LIVE: 
      {
      ilog("PROFILE: Entering LIVE sync, creating indexes/constraints as needed: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      if ( get_state() != INDEXATION::START )
      {
        auto irreversible_cached_data = move_irreveresible_blocks(cached_data, _irreversible_block_num );
        force_trigger_flush_with_all_data( irreversible_cached_data, _irreversible_block_num );
      }

      _trigger.reset();
      _dumper.reset();
      _indexes_controler.enable_indexes();
      _indexes_controler.enable_constrains();
      std::thread([this]() {
        _indexes_controler.poll_and_create_indexes();
      }).detach();
      _dumper = std::make_unique< livesync_data_dumper >(
        _db_url
        , _main_plugin
        , _chain_db
        , theApp
        , _psql_operations_threads_number
        , _psql_transactions_threads_number
        , _psql_account_operations_threads_number
        , _psql_first_block
        , _write_ahead_log
        );
      _trigger = std::make_unique< live_flush_trigger >(
        [this]( cached_data_t& cached_data, int last_block_num ) {
          force_trigger_flush_with_all_data( cached_data, last_block_num );
        }
        );
      flush_all_data_to_reversible( cached_data );
      ilog("PROFILE: Entered LIVE sync from start state: ${t} s ${b}",("t",(fc::time_point::now() - _start_state_time).to_seconds())("b",last_block_num));
      break;
      }
   case INDEXATION::WAIT:
      ilog("PROFILE: Entering WAIT sync: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      _trigger.reset();
      _dumper.reset();
      _trigger = std::make_shared< fake_flush_trigger >();
      _dumper = std::make_shared< fake_data_dumper >();
      ilog("PROFILE: Entered WAIT sync from start state: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      break;
     ilog("PROFILE: Entering WAIT sync: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      _trigger.reset();
      _dumper.reset();
      _trigger = std::make_shared< fake_flush_trigger >();
      _dumper = std::make_shared< fake_data_dumper >();
      ilog("PROFILE: Entered WAIT sync from start state: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      break;
    case INDEXATION::REINDEX_WAIT:
      ilog("PROFILE: Entering REINDEX_WAIT sync: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      _trigger.reset();
      _dumper.reset();
      _trigger = std::make_shared< fake_flush_trigger >();
      _dumper = std::make_shared< fake_data_dumper >();
      ilog("PROFILE: Entered REINDEX_WAIT sync: ${t} s",("t",(fc::time_point::now() - _start_state_time).to_seconds()));
      break;
    default:
      FC_ASSERT( false, "Unknown INDEXATION state" );
  }

  set_state(state);
}

void
indexation_state::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
  _trigger->flush( cached_data, last_block_num, _irreversible_block_num );
}

void
indexation_state::force_trigger_flush_with_all_data( cached_data_t& cached_data, int last_block_num ) {
  if ( cached_data.blocks.empty() ) {
    return;
  }
  _dumper->trigger_data_flush( cached_data, last_block_num );
}

/* After P2P sync there are still reversible blocks in the cached_data, we have to push them to reverisble tables
 * using live sync dumper.
 */
void
indexation_state::flush_all_data_to_reversible( cached_data_t& cached_data ) {
  ilog("Flushing reversible blocks...");
  while ( !cached_data.blocks.empty() ) {
    const auto current_block = cached_data.blocks.front().block_number;
    cached_data_t reversible_data{0};

    move_items_upto_block( reversible_data.blocks, cached_data.blocks, current_block );
    move_items_upto_block( reversible_data.transactions, cached_data.transactions, current_block );
    move_items_upto_block( reversible_data.transactions_multisig, cached_data.transactions_multisig, current_block );
    move_items_upto_block( reversible_data.operations, cached_data.operations, current_block );
    move_items_upto_block( reversible_data.accounts, cached_data.accounts, current_block );
    move_items_upto_block( reversible_data.account_operations, cached_data.account_operations, current_block );
    move_items_upto_block( reversible_data.applied_hardforks, cached_data.applied_hardforks, current_block );

    force_trigger_flush_with_all_data( reversible_data, current_block );
  }

  ilog( "Flushed all reversible blocks" );
}

void
indexation_state::on_irreversible_block( uint32_t block_num ) {
  _irreversible_block_num = block_num;
}

void
indexation_state::on_switch_fork( cached_data_t& cached_data, uint32_t block_num ) {
  if ( get_state() != INDEXATION::P2P ) {
    return;
  }

  ilog( "During P2P syncing a fork was raised, chached reversible data are removing...." );
  erase_items_greater_than_block( cached_data.blocks, block_num );
  erase_items_greater_than_block( cached_data.transactions, block_num );
  erase_items_greater_than_block( cached_data.transactions_multisig, block_num );
  erase_items_greater_than_block( cached_data.operations, block_num );
  erase_items_greater_than_block( cached_data.accounts, block_num );
  erase_items_greater_than_block( cached_data.account_operations, block_num );
  erase_items_greater_than_block( cached_data.applied_hardforks, block_num );

  ilog( "Cached reversible data removed" );
}

bool
indexation_state::collect_blocks() const {
  return static_cast< uint32_t >( get_state() ) & COLLECT_BLOCKS_MASK;
}

indexation_state::INDEXATION
indexation_state::get_state() const {
    using namespace std::literals;

    if ( _cached_state_value.has_value() )
        return _cached_state_value.value();

    indexation_state::INDEXATION result = INDEXATION::START;
    queries_commit_data_processor state_getter(
            _db_url
            , "Get synchronization state"
            , ""
            , [&result](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
                static const std::unordered_map< std::string, INDEXATION > string_to_enum = {
                      {"START", INDEXATION::START}
                    , {"WAIT", INDEXATION::WAIT}
                    , {"REINDEX_WAIT", INDEXATION::REINDEX_WAIT}
                    , {"REINDEX", INDEXATION::REINDEX}
                    , {"P2P", INDEXATION::P2P}
                    , {"LIVE", INDEXATION::LIVE}
                };

                pqxx::result data = tx.exec("select hive.get_sync_state() as _result;");
                FC_ASSERT( !data.empty(), "No response from database" );
                FC_ASSERT( data.size() == 1, "Wrong data size" );
                const auto& record = data[0];
                auto state_text = record[ "_result" ].as<std::string>();

                auto enum_it = string_to_enum.find( state_text );
                FC_ASSERT( enum_it != string_to_enum.end(), "Unknown hafd.sync_state value" );
                result = enum_it->second;

                return data_processor::data_processing_status();
            }
            , nullptr
            , theApp
    );

    state_getter.trigger(data_processor::data_chunk_ptr(), 0);
    state_getter.join();

    _cached_state_value = result;

    return result;
}

void
indexation_state::set_state( INDEXATION _new_state ) {
    using namespace std::literals;

    queries_commit_data_processor state_setter(
            _db_url
            , "Set synchronization state"
            , ""
            , [_new_state](const data_processor::data_chunk_ptr&, transaction_controllers::transaction& tx) -> data_processor::data_processing_status {
                static const std::unordered_map< INDEXATION, std::string > enum_to_string = {
                          {INDEXATION::START, "'START'::hafd.sync_state"}
                        , {INDEXATION::WAIT, "'WAIT'::hafd.sync_state"}
                        , {INDEXATION::REINDEX_WAIT, "'REINDEX_WAIT'::hafd.sync_state"}
                        , {INDEXATION::REINDEX, "'REINDEX'::hafd.sync_state"}
                        , {INDEXATION::P2P, "'P2P'::hafd.sync_state"}
                        , {INDEXATION::LIVE, "'LIVE'::hafd.sync_state"}
                };

                auto enum_it = enum_to_string.find( _new_state );
                FC_ASSERT( enum_it != enum_to_string.end(), "Unknown enum  value" );
                auto value_to_set = enum_it->second;

                std::string query =  "select hive.set_sync_state("s + value_to_set + ");"s;

                pqxx::result data = tx.exec(query);

                return data_processor::data_processing_status();
            }
            , nullptr
            , theApp
    );

    state_setter.trigger(data_processor::data_chunk_ptr(), 0);
    state_setter.join();

    _cached_state_value.reset();
}

}}} // namespace hive{ namespace plugins{ namespace sql_serializer

