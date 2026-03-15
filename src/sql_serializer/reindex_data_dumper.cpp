#include <hive/plugins/sql_serializer/reindex_data_dumper.h>

#include <exception>


namespace hive{ namespace plugins{ namespace sql_serializer {
  reindex_data_dumper::reindex_data_dumper(
      const std::string& db_url
    , appbase::application& app
    , uint32_t operations_threads
    , uint32_t transactions_threads
    , uint32_t account_operation_threads
    , uint32_t pruning_tail_size
    , bool synchronous_mode) : app(app), _db_url(db_url), _synchronous_mode(synchronous_mode) {
    using namespace std::string_literals;
    ilog( "Starting reindexing dump to database with ${o} operations and ${t} transactions threads, synchronous_mode=${s}",
          ("o", operations_threads )("t", transactions_threads)("s", synchronous_mode) );
    _transactions_controller = transaction_controllers::build_own_transaction_controller( db_url, "reindex dumper", app );
    _end_massive_sync_processor = std::make_unique< end_massive_sync_processor >( db_url, app );
    constexpr auto ONE_THREAD_WRITERS_NUMBER = 4; // a thread for dumping blocks + a thread dumping multisignatures + a thread for accounts
    auto NUMBER_OF_PROCESSORS_THREADS = ONE_THREAD_WRITERS_NUMBER + operations_threads + transactions_threads + account_operation_threads;
    auto execute_end_massive_sync_callback = [this, pruning_tail_size](block_num_rendezvous_trigger::BLOCK_NUM _block_num ) {
      if (_block_num) {
          _end_massive_sync_processor->trigger_block_number(_block_num);
      }
    };

    auto api_trigger = std::make_shared< block_num_rendezvous_trigger >( NUMBER_OF_PROCESSORS_THREADS, execute_end_massive_sync_callback );
    _api_trigger = api_trigger;

    _block_writer = std::make_unique<block_data_container_t_writer>(db_url, "Block data writer", "block", api_trigger, app);

    _transaction_writer = std::make_unique<transaction_data_container_t_writer>( transactions_threads, db_url, "Transaction data writer", "trx", api_trigger, app);

    _transaction_multisig_writer = std::make_unique<transaction_multisig_data_container_t_writer>(db_url, "Transaction multisig data writer", "trx_multi", api_trigger, app);

    _operation_writer = std::make_unique<operation_data_container_t_writer>( operations_threads, db_url, "Operation data writer", "op", api_trigger, app);
    _account_writer = std::make_unique<accounts_data_container_t_writer>( db_url, "Accounts data writer", "account", api_trigger, app);
    _account_operations_writer = std::make_unique< account_operations_data_container_t_writer >( account_operation_threads, db_url, "Account operations data writer", "account_op", api_trigger, app);
    _applied_hardforks_writer = std::make_unique< applied_hardforks_container_t_writer >( db_url, "Hardfork data writer", "hardfork", api_trigger, app);

    mark_irreversible_data_as_dirty( true );
  }

  reindex_data_dumper::~reindex_data_dumper() {
    ilog( "Reindex dumper is closing...." );
    try {
      join();
    } FC_CAPTURE_AND_LOG(())
    ilog( "Reindex dumper closed" );
  }

  void reindex_data_dumper::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
    if ( _synchronous_mode ) {
      trigger_synchronous_flush( cached_data, last_block_num );
      return;
    }

    _block_writer->trigger( std::move( cached_data.blocks ), last_block_num );
    _transaction_writer->trigger( std::move( cached_data.transactions ), last_block_num);
    _operation_writer->trigger( std::move( cached_data.operations ), last_block_num );
    _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), last_block_num );
    _account_writer->trigger( std::move( cached_data.accounts ), last_block_num );
    _account_operations_writer->trigger( std::move( cached_data.account_operations ), last_block_num );
    _applied_hardforks_writer->trigger( std::move( cached_data.applied_hardforks ), last_block_num );
  }

  void reindex_data_dumper::trigger_synchronous_flush( cached_data_t& cached_data, int last_block_num ) {
    // When FK constraints are NOT dropped (below threshold), parallel writers would
    // cause FK violations due to circular dependencies between tables (e.g.,
    // blocks.producer_account_id -> accounts.id and accounts.block_num -> blocks.num).
    // Instead, write all data in a single transaction so all rows are visible atomically
    // at commit time, satisfying all FK constraints (including DEFERRED ones).
    auto transaction = _transactions_controller->openTx();

    auto copy_to_table = [&transaction](const auto& data, const char* table, const char* cols) {
      if ( data.empty() )
        return;
      transaction->run_in_transaction([&](pqxx::work& work) {
        pqxx::stream_to stream = pqxx::stream_to::raw_table(work, table, cols);
        for ( auto it = data.cbegin(); it != data.cend(); ++it )
          write_row_to_stream(stream, *it);
        stream.complete();
      });
    };

    // Order matters for IMMEDIATE FK constraints within the transaction:
    // 1. blocks first (no IMMEDIATE FKs to other tables; producer_account_id FK is DEFERRED)
    // 2. accounts (block_num -> blocks.num)
    // 3. transactions (block_num -> blocks.num)
    // 4. operations (no FKs)
    // 5. transactions_multisig (trx_hash -> transactions.trx_hash)
    // 6. applied_hardforks (block_num -> blocks.num, hardfork_vop_id -> operations.id)
    // 7. account_operations (account_id -> accounts.id, operation_id -> operations.id)
    copy_to_table(cached_data.blocks, hive_blocks::TABLE, hive_blocks::COLS);
    copy_to_table(cached_data.accounts, hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::TABLE,
                  hive_accounts<std::vector<PSQL::processing_objects::account_data_t>>::COLS);
    copy_to_table(cached_data.transactions, hive_transactions<std::vector<PSQL::processing_objects::process_transaction_t>>::TABLE,
                  hive_transactions<std::vector<PSQL::processing_objects::process_transaction_t>>::COLS);
    copy_to_table(cached_data.operations, hive_operations<std::vector<PSQL::processing_objects::process_operation_t>>::TABLE,
                  hive_operations<std::vector<PSQL::processing_objects::process_operation_t>>::COLS);
    copy_to_table(cached_data.transactions_multisig, hive_transactions_multisig::TABLE, hive_transactions_multisig::COLS);
    copy_to_table(cached_data.applied_hardforks, hive_applied_hardforks::TABLE, hive_applied_hardforks::COLS);
    copy_to_table(cached_data.account_operations, hive_account_operations<std::vector<PSQL::processing_objects::account_operation_data_t>>::TABLE,
                  hive_account_operations<std::vector<PSQL::processing_objects::account_operation_data_t>>::COLS);

    transaction->commit();

    // Clear the data to match the behavior of the parallel path (data is moved out).
    cached_data.blocks.clear();
    cached_data.transactions.clear();
    cached_data.operations.clear();
    cached_data.transactions_multisig.clear();
    cached_data.accounts.clear();
    cached_data.account_operations.clear();
    cached_data.applied_hardforks.clear();

    // Fire the end_massive_sync_processor directly, bypassing the rendezvous trigger
    // which expects reports from each parallel writer thread.
    if ( last_block_num > 0 ) {
      _end_massive_sync_processor->trigger_block_number( static_cast<uint32_t>(last_block_num) );
    }
  }

  void reindex_data_dumper::join() {
    // _end_massive_sync_processor should be joined last
    join_processors(
        *_block_writer
      , *_transaction_writer
      , *_transaction_multisig_writer
      , *_operation_writer
      , *_account_writer
      , *_account_operations_writer
      , *_applied_hardforks_writer
      , *_end_massive_sync_processor
    );

    mark_irreversible_data_as_dirty( false );
  }

  void reindex_data_dumper::mark_irreversible_data_as_dirty( bool is_dirty ) {
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
}}} // namespace hive::plugins::sql_serializer


