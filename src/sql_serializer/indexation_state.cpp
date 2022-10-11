#include <hive/plugins/sql_serializer/indexation_state.hpp>

#include <hive/plugins/sql_serializer/cached_data.h>
#include <hive/plugins/sql_serializer/sql_serializer_plugin.hpp>
#include <hive/plugins/sql_serializer/livesync_data_dumper.h>
#include <hive/plugins/sql_serializer/reindex_data_dumper.h>

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
  , uint32_t psql_transactions_threads_number
  , uint32_t psql_operations_threads_number
  , uint32_t psql_account_operations_threads_number
  , uint32_t psql_index_threshold
  , uint32_t psql_livesync_threshold
)
  : _main_plugin( main_plugin )
  , _chain_db( chain_db )
  , _db_url( db_url )
  , _psql_transactions_threads_number( psql_transactions_threads_number )
  , _psql_operations_threads_number( psql_operations_threads_number )
  , _psql_account_operations_threads_number( psql_account_operations_threads_number )
  , _psql_livesync_threshold( psql_livesync_threshold )
  , _irreversible_block_num( NO_IRREVERSIBLE_BLOCK )
  , _indexes_controler( db_url, psql_index_threshold )
{
  cached_data_t empty_data{0};
  update_state( INDEXATION::START, empty_data, 0 );

  _on_irreversible_block_conn = _chain_db.add_irreversible_block_handler(
      [this]( uint32_t block_num ){ on_irreversible_block( block_num ); }
    , _main_plugin
  );
}

void
indexation_state::on_pre_reindex( cached_data_t& cached_data, int last_block_num, uint32_t number_of_blocks_to_add ) {
  if ( _state != INDEXATION::START ) {
    // on_end_of_syncing may already change the state to live
    return;
  }

  if ( can_move_to_livesync() ) {
    cached_data_t empty_cache{0};
    update_state( INDEXATION::LIVE, empty_cache, 0 );
    return;
  }

  update_state( INDEXATION::REINDEX, cached_data, last_block_num, number_of_blocks_to_add );
}

void
indexation_state::on_post_reindex( cached_data_t& cached_data, uint32_t last_block_num, uint32_t _stop_replay_at ) {
  if ( _state != INDEXATION::REINDEX ) {
    // on_end_of_syncing may already change the state
    return;
  }

  // when option stop-replay-at is used then we finish synchronization when limit block is reached
  if ( _stop_replay_at && _stop_replay_at == last_block_num ) {
    force_trigger_flush_with_all_data( cached_data, last_block_num );
    _trigger.reset();
    _dumper.reset();
    _indexes_controler.enable_indexes();
    _indexes_controler.enable_constrains();
    return;
  }

  update_state( INDEXATION::P2P, cached_data, last_block_num, UNKNOWN );
}

void
indexation_state::on_end_of_syncing( cached_data_t& cached_data, int last_block_num ) {
  if ( _state == INDEXATION::LIVE ) {
    return;
  }
  update_state( INDEXATION::LIVE, cached_data, last_block_num, UNKNOWN );
}

void
indexation_state::on_first_block() {
  if ( _state != INDEXATION::START ) {
    // end_of_syncing may already change the state
    return;
  }
  cached_data_t empty_cache{0};
  if ( can_move_to_livesync() ) {
    update_state( INDEXATION::LIVE, empty_cache, 0 );
    return;
  }

  update_state( INDEXATION::P2P, empty_cache, 0 );
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
  FC_ASSERT( _state != INDEXATION::LIVE, "Move from LIVE state is illegal" );
  switch ( state ) {
    case INDEXATION::START:
      ilog( "Entered START sync state" );
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
      ilog("Entered P2P sync");
      break;
    case INDEXATION::REINDEX:
      ilog("Entering REINDEX sync...");
      FC_ASSERT( _state == INDEXATION::START, "Reindex always starts after START" );
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
        , _psql_operations_threads_number
        , _psql_transactions_threads_number
        , _psql_account_operations_threads_number
      );
      _trigger = std::make_unique< reindex_flush_trigger >(
        [this]( cached_data_t& cached_data, int last_block_num ) {
          force_trigger_flush_with_all_data( cached_data, last_block_num );
        }
      );
      ilog("Entered REINDEX sync");
      break;
      case INDEXATION::LIVE: {
        ilog("Entering LIVE sync...");
        if ( _state != INDEXATION::START ) {
          auto irreversible_cached_data = move_irreveresible_blocks(cached_data, _irreversible_block_num );
          force_trigger_flush_with_all_data( irreversible_cached_data, _irreversible_block_num );
        }
        _trigger.reset();
        _dumper.reset();
        _indexes_controler.enable_indexes();
        _indexes_controler.enable_constrains();
        _dumper = std::make_unique< livesync_data_dumper >(
          _db_url
          , _main_plugin
          , _chain_db
          , _psql_operations_threads_number
          , _psql_transactions_threads_number
          , _psql_account_operations_threads_number
          );
        _trigger = std::make_unique< live_flush_trigger >(
          [this]( cached_data_t& cached_data, int last_block_num ) {
            force_trigger_flush_with_all_data( cached_data, last_block_num );
          }
          );
        flush_all_data_to_reversible( cached_data );
        ilog("Entered LIVE sync");
        break;
      }
    default:
      FC_ASSERT( false, "Unknown INDEXATION state" );
  }
  _state = state;
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
  ilog( "Flushing ${d} reversible blocks..." );
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
  if ( _state != INDEXATION::P2P ) {
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

}}} // namespace hive{ namespace plugins{ namespace sql_serializer

