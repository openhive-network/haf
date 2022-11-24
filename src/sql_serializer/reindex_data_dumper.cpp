#include <hive/plugins/sql_serializer/reindex_data_dumper.h>

#include <hive/plugins/sql_serializer/synchronicity_data.hpp>

#include <exception>


namespace hive{ namespace plugins{ namespace sql_serializer {
  template<bool force_synchronicity>
  reindex_data_dumper<force_synchronicity>::reindex_data_dumper(
      const std::string& db_url
    , uint32_t operations_threads
    , uint32_t transactions_threads
    , uint32_t account_operation_threads ) {
    ilog("reindex data dumper has ${mode} mode enabled",("mode", force_synchronicity ? "synchronicity" : "asynchronicity"));

    std::shared_ptr< block_num_rendezvous_trigger > api_trigger;

    if( force_synchronicity )
    {
      operations_threads        = 1;
      transactions_threads      = 1;
      account_operation_threads = 1;

      synchronicity = synchronicity_data::synchronicity_data_ptr( new synchronicity_data( force_synchronicity, db_url, "reindex dumper 2" ) );
    }

    constexpr auto ONE_THREAD_WRITERS_NUMBER = 4; // a thread for dumping blocks + a thread dumping multisignatures + a thread for accounts
    auto NUMBER_OF_PROCESSORS_THREADS = ONE_THREAD_WRITERS_NUMBER + operations_threads + transactions_threads + account_operation_threads;
    ilog( "Starting reindexing dump to database with ${o} operations and ${t} transactions and ${ao} account operations threads", ("o", operations_threads )("t", transactions_threads)("ao", account_operation_threads) );

    _transactions_controller = transaction_controllers::build_own_transaction_controller( db_url, "reindex dumper" );
    _end_massive_sync_processor = std::make_unique< end_massive_sync_processor >( db_url, synchronicity );

    if( !force_synchronicity )
    {
      auto execute_end_massive_sync_callback = [this](block_num_rendezvous_trigger::BLOCK_NUM _block_num ){
        if ( !_block_num ) {
          return;
        }
        _end_massive_sync_processor->trigger_block_number( _block_num );
      };
      api_trigger = std::make_shared< block_num_rendezvous_trigger >( NUMBER_OF_PROCESSORS_THREADS, execute_end_massive_sync_callback );
    }


    _block_writer = std::make_unique<block_data_container_t_writer>( db_url, "Block data writer", api_trigger, synchronicity );

    _transaction_writer = std::make_unique<transaction_data_container_t_writer>( transactions_threads, db_url, "Transaction data writer", api_trigger, synchronicity );

    _transaction_multisig_writer = std::make_unique<transaction_multisig_data_container_t_writer>( db_url, "Transaction multisig data writer", api_trigger, synchronicity );

    _operation_writer = std::make_unique<operation_data_container_t_writer>( operations_threads, db_url, "Operation data writer", api_trigger, synchronicity );
    _account_writer = std::make_unique<accounts_data_container_t_writer>( db_url, "Accounts data writer", api_trigger, synchronicity );
    _account_operations_writer = std::make_unique<account_operations_data_container_t_writer>( account_operation_threads, db_url, "Account operations data writer", api_trigger, synchronicity );
    _applied_hardforks_writer = std::make_unique< applied_hardforks_container_t_writer >( db_url, "Hardfork data writer", api_trigger, synchronicity);

    mark_irreversible_data_as_dirty( true );
  }

  template<bool force_synchronicity>
  reindex_data_dumper<force_synchronicity>::~reindex_data_dumper() {
    ilog( "Reindex dumper is closing...." );
    reindex_data_dumper::join();
    ilog( "Reindex dumper closed" );
  }

  template<bool force_synchronicity>
  void reindex_data_dumper<force_synchronicity>::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
    if( force_synchronicity )
    {
      FC_ASSERT( synchronicity );

      synchronicity->openTx();

      _block_writer->trigger( std::move( cached_data.blocks ), last_block_num );
      _block_writer->complete_data_processing();

      _transaction_writer->trigger( std::move( cached_data.transactions ), last_block_num);
      _transaction_writer->complete_data_processing();

      _operation_writer->trigger( std::move( cached_data.operations ), last_block_num );
      _operation_writer->complete_data_processing();

      _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), last_block_num );
      _transaction_multisig_writer->complete_data_processing();

      _account_writer->trigger( std::move( cached_data.accounts ), last_block_num );
      _account_writer->complete_data_processing();

      _account_operations_writer->trigger( std::move( cached_data.account_operations ), last_block_num );
      _account_operations_writer->complete_data_processing();

      _applied_hardforks_writer->trigger( std::move( cached_data.applied_hardforks ), last_block_num );
      _applied_hardforks_writer->complete_data_processing();

      _end_massive_sync_processor->trigger_block_number( last_block_num );
      _end_massive_sync_processor->complete_data_processing();

      synchronicity->commit();
    }
    else
    {
      _block_writer->trigger( std::move( cached_data.blocks ), last_block_num );
      _transaction_writer->trigger( std::move( cached_data.transactions ), last_block_num);
      _operation_writer->trigger( std::move( cached_data.operations ), last_block_num );
      _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), last_block_num );
      _account_writer->trigger( std::move( cached_data.accounts ), last_block_num );
      _account_operations_writer->trigger( std::move( cached_data.account_operations ), last_block_num );
      _applied_hardforks_writer->trigger( std::move( cached_data.applied_hardforks ), last_block_num );
    }
  }

  template<bool force_synchronicity>
  bool reindex_data_dumper<force_synchronicity>::is_synchronicity() const
  {
    return force_synchronicity;
  }

  template<bool force_synchronicity>
  void reindex_data_dumper<force_synchronicity>::join() {
    join_writers(
        *_block_writer
      , *_transaction_writer
      , *_transaction_multisig_writer
      , *_operation_writer
      , *_account_writer
      , *_account_operations_writer
      , *_end_massive_sync_processor
      , *_applied_hardforks_writer
    );

    mark_irreversible_data_as_dirty( false );
  }

  template<bool force_synchronicity>
  void reindex_data_dumper<force_synchronicity>::mark_irreversible_data_as_dirty( bool is_dirty ) {
    auto transaction = _transactions_controller->openTx();
    std::string sql_command;
    if ( is_dirty ) {
      sql_command = "SELECT hive.set_irreversible_dirty();";
    }
    else {
      sql_command = "SELECT hive.set_irreversible_not_dirty();";
    }

    transaction->exec( sql_command );
    transaction->commit();
  }

  template
  class reindex_data_dumper<true>;
  template
  class reindex_data_dumper<false>;
}}} // namespace hive::plugins::sql_serializer


