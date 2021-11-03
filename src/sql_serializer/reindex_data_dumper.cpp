#include <hive/plugins/sql_serializer/reindex_data_dumper.h>

#include <exception>


namespace hive{ namespace plugins{ namespace sql_serializer {
  reindex_data_dumper::reindex_data_dumper(
      const std::string& db_url
    , uint32_t operations_threads
    , uint32_t transactions_threads
    , uint32_t account_operation_threads ) {
    ilog( "Starting reindexing dump to database with ${o} operations and ${t} transactions threads", ("o", operations_threads )("t", transactions_threads) );
    _end_massive_sync_processor = std::make_unique< end_massive_sync_processor >( db_url );
    constexpr auto ONE_THREAD_WRITERS_NUMBER = 3; // a thread for dumping blocks + a thread dumping multisignatures + a thread for accounts
    auto NUMBER_OF_PROCESSORS_THREADS = ONE_THREAD_WRITERS_NUMBER + operations_threads + transactions_threads + account_operation_threads;
    auto execute_end_massive_sync_callback = [this](block_num_rendezvous_trigger::BLOCK_NUM _block_num ){
      _end_massive_sync_processor->trigger_block_number( _block_num );
    };
    auto api_trigger = std::make_shared< block_num_rendezvous_trigger >( NUMBER_OF_PROCESSORS_THREADS, execute_end_massive_sync_callback );

    _block_writer = std::make_unique<block_data_container_t_writer>(db_url, "Block data writer", api_trigger);

    _transaction_writer = std::make_unique<transaction_data_container_t_writer>( transactions_threads, db_url, "Transaction data writer", api_trigger);

    _transaction_multisig_writer = std::make_unique<transaction_multisig_data_container_t_writer>(db_url, "Transaction multisig data writer", api_trigger);

    _operation_writer = std::make_unique<operation_data_container_t_writer>( operations_threads, db_url, "Operation data writer", api_trigger);
    _account_writer = std::make_unique<accounts_data_container_t_writer>( db_url, "Accounts data writer", api_trigger);
    _account_operations_writer = std::make_unique< account_operations_data_container_t_writer >( account_operation_threads, db_url, "Account operations data writer", api_trigger);
  }

  reindex_data_dumper::~reindex_data_dumper() {
    ilog( "Reindex dumper is closing...." );
    reindex_data_dumper::join();
    ilog( "Reindex dumper closed" );
  }

  void reindex_data_dumper::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
    _block_writer->trigger( std::move( cached_data.blocks ), false, last_block_num );
    _transaction_writer->trigger( std::move( cached_data.transactions ), last_block_num);
    _operation_writer->trigger( std::move( cached_data.operations ), last_block_num );
    _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), false, last_block_num );
    _account_writer->trigger( std::move( cached_data.accounts ), false, last_block_num );
    _account_operations_writer->trigger( std::move( cached_data.account_operations ), last_block_num );
  }

  void reindex_data_dumper::join() {
    join_writers(
        *_block_writer
      , *_transaction_writer
      , *_transaction_multisig_writer
      , *_operation_writer
      , *_account_writer
      , *_account_operations_writer
      , *_end_massive_sync_processor
    );
  }

  void reindex_data_dumper::wait_for_data_processing_finish()
  {
    _block_writer->complete_data_processing();
    _transaction_writer->complete_data_processing();
    _transaction_multisig_writer->complete_data_processing();
    _operation_writer->complete_data_processing();
    _account_writer->complete_data_processing();
    _account_operations_writer->complete_data_processing();

    _end_massive_sync_processor->complete_data_processing();
  }
}}} // namespace hive::plugins::sql_serializer


