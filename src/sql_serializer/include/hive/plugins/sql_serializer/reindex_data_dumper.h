#pragma once

#include <hive/plugins/sql_serializer/string_data_processor.h>
#include <hive/plugins/sql_serializer/queries_commit_data_processor.h>
#include <hive/plugins/sql_serializer/data_dumper.h>

#include <hive/plugins/sql_serializer/table_data_writer.h>
#include <hive/plugins/sql_serializer/tables_descriptions.h>
#include <hive/plugins/sql_serializer/chunks_for_writers_spillter.h>

#include <hive/plugins/sql_serializer/end_massive_sync_processor.hpp>
#include <hive/plugins/sql_serializer/cached_data.h>

#include <memory>
#include <string>
#include <exception>

namespace hive::plugins::sql_serializer {

  namespace
  {
    template<bool sequential_mode>
    struct sequential_mode_table_data_writer_type_helper;

    template<>
    struct sequential_mode_table_data_writer_type_helper<true>
    {
      using processor_t = hive::plugins::sql_serializer::string_data_processor;
    };

    template<>
    struct sequential_mode_table_data_writer_type_helper<false>
    {
      using processor_t = hive::plugins::sql_serializer::queries_commit_data_processor;
    };
  }

  template<bool sequential_mode = false>
  class reindex_data_dumper: public data_dumper {
  public:
    reindex_data_dumper(
        const std::string& db_url
      , uint32_t operations_threads
      , uint32_t transactions_threads
      , uint32_t account_operation_threads
    );

    ~reindex_data_dumper();
    reindex_data_dumper(reindex_data_dumper&) = delete;
    reindex_data_dumper(reindex_data_dumper&&) = delete;
    reindex_data_dumper& operator=(reindex_data_dumper&&) = delete;
    reindex_data_dumper& operator=(reindex_data_dumper&) = delete;

    void trigger_data_flush( cached_data_t& cached_data, int last_block_num ) override;
  private:
    void join();
    void mark_irreversible_data_as_dirty( bool is_dirty );

    using block_data_container_t_writer = table_data_writer<hive_blocks, typename sequential_mode_table_data_writer_type_helper<sequential_mode>::processor_t>;
    using accounts_data_container_t_writer = table_data_writer< hive_accounts, typename sequential_mode_table_data_writer_type_helper<sequential_mode>::processor_t>;

    using transaction_data_container_t_writer = chunks_for_sql_writers_splitter<
      table_data_writer<
        hive_transactions<
          container_view<
            std::vector<PSQL::processing_objects::process_transaction_t>
          >
        >
      >
    >;
    using transaction_multisig_data_container_t_writer = table_data_writer<hive_transactions_multisig>;
    using operation_data_container_t_writer = chunks_for_sql_writers_splitter<
      table_data_writer<
        hive_operations<
          container_view<
            std::vector<PSQL::processing_objects::process_operation_t>
          >
        >
      >
    >;
    using account_operations_data_container_t_writer = chunks_for_sql_writers_splitter<
      table_data_writer<
        hive_account_operations<
          container_view< std::vector< PSQL::processing_objects::account_operation_data_t >
          >
        >
      >
    >;

    std::unique_ptr< block_data_container_t_writer > _block_writer;
    std::unique_ptr< transaction_data_container_t_writer > _transaction_writer;
    std::unique_ptr< transaction_multisig_data_container_t_writer > _transaction_multisig_writer;
    std::unique_ptr< operation_data_container_t_writer > _operation_writer;
    std::unique_ptr< accounts_data_container_t_writer > _account_writer;
    std::unique_ptr< account_operations_data_container_t_writer > _account_operations_writer;

    std::unique_ptr<end_massive_sync_processor> _end_massive_sync_processor;
    std::shared_ptr< transaction_controllers::transaction_controller > _transactions_controller;

    std::string _blocks;
    std::string _accounts;
  };

} // namespace hive::plugins::sql_serializer


namespace hive{ namespace plugins{ namespace sql_serializer {

  template<bool sequential_mode>
  reindex_data_dumper<sequential_mode>::reindex_data_dumper(
      const std::string& db_url
    , uint32_t operations_threads
    , uint32_t transactions_threads
    , uint32_t account_operation_threads
    )
    {
    ilog( "Starting reindexing dump to database with ${o} operations and ${t} transactions threads", ("o", operations_threads )("t", transactions_threads) );
    _transactions_controller = transaction_controllers::build_own_transaction_controller( db_url, "reindex dumper" );
    _end_massive_sync_processor = std::make_unique< end_massive_sync_processor >( db_url );
    constexpr auto ONE_THREAD_WRITERS_NUMBER = 3; // a thread for dumping blocks + a thread dumping multisignatures + a thread for accounts
    auto NUMBER_OF_PROCESSORS_THREADS = ONE_THREAD_WRITERS_NUMBER + operations_threads + transactions_threads + account_operation_threads;
    auto execute_end_massive_sync_callback = [this](block_num_rendezvous_trigger::BLOCK_NUM _block_num ){
      if ( !_block_num ) {
        return;
      }
      _end_massive_sync_processor->trigger_block_number( _block_num );
    };

    auto api_trigger = std::make_shared< block_num_rendezvous_trigger >( NUMBER_OF_PROCESSORS_THREADS, execute_end_massive_sync_callback );

    if constexpr (sequential_mode)
    {
      const auto _blocks_callback = [this](std::string&& s){ _blocks = std::move(s); };
      const auto _accounts_callback = [this](std::string&& s){ _accounts = std::move(s); };

      _block_writer = std::make_unique<block_data_container_t_writer>(_blocks_callback, "Block data writer", api_trigger);
      _account_writer = std::make_unique<accounts_data_container_t_writer>(_accounts_callback, "Accounts data writer", api_trigger);
    }
    else
    {
      _block_writer = std::make_unique<block_data_container_t_writer>(db_url, "Block data writer", api_trigger);
      _account_writer = std::make_unique<accounts_data_container_t_writer>(db_url, "Accounts data writer", api_trigger);
    }

    _transaction_writer = std::make_unique<transaction_data_container_t_writer>( transactions_threads, db_url, "Transaction data writer", api_trigger);
    _transaction_multisig_writer = std::make_unique<transaction_multisig_data_container_t_writer>(db_url, "Transaction multisig data writer", api_trigger);
    _operation_writer = std::make_unique<operation_data_container_t_writer>( operations_threads, db_url, "Operation data writer", api_trigger);
    _account_operations_writer = std::make_unique< account_operations_data_container_t_writer >( account_operation_threads, db_url, "Account operations data writer", api_trigger);

    mark_irreversible_data_as_dirty( true );
  }

  template<bool sequential_mode>
  reindex_data_dumper<sequential_mode>::~reindex_data_dumper() {
    ilog( "Reindex dumper is closing...." );
    reindex_data_dumper::join();
    ilog( "Reindex dumper closed" );
  }

  template<bool sequential_mode>
  void reindex_data_dumper<sequential_mode>::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
    if constexpr (!sequential_mode)
    {
      _block_writer->trigger( std::move( cached_data.blocks ), last_block_num );
      _account_writer->trigger( std::move( cached_data.accounts ), last_block_num );
    }
    else
    {
      _block_writer->trigger( std::move( cached_data.blocks ), last_block_num );
      _account_writer->trigger( std::move( cached_data.accounts ), last_block_num );

      _block_writer->complete_data_processing();
      _account_writer->complete_data_processing();

      if ( !_blocks.empty() ) {
        ilog("Sequentially pushing blocks and accounts");
        auto transaction = _transactions_controller->openTx();

        const std::string block_to_dump = "INSERT INTO hive.blocks VALUES " + std::move( _blocks );
        transaction->exec( block_to_dump );

        if(!_accounts.empty())
        {
          const std::string accounts_to_dump = "INSERT INTO hive.accounts VALUES " + std::move( _accounts );
          transaction->exec( accounts_to_dump );
        }

        transaction->commit();
        ilog("Commited pushing blocks and accounts");
      }
    }

    _transaction_writer->trigger( std::move( cached_data.transactions ), last_block_num);
    if constexpr (sequential_mode)
      _transaction_writer->complete_data_processing();

    _operation_writer->trigger( std::move( cached_data.operations ), last_block_num );
    if constexpr (sequential_mode)
      _operation_writer->complete_data_processing();

    ilog("Starting independent writers");
    _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), last_block_num );
    _account_operations_writer->trigger( std::move( cached_data.account_operations ), last_block_num );
    ilog("Started independent writers");
  }

  template<bool sequential_mode>
  void reindex_data_dumper<sequential_mode>::join() {
    if constexpr (sequential_mode)
    {
      ilog("Joining in sequential mode");
      join_writers(
        *_transaction_multisig_writer,
        *_account_operations_writer
      );
      ilog("Joined in sequential mode");
    }
    else
    {
      ilog("Joining in parallel mode");
      join_writers(
          *_block_writer
        , *_transaction_writer
        , *_transaction_multisig_writer
        , *_operation_writer
        , *_account_writer
        , *_account_operations_writer
        , *_end_massive_sync_processor
      );
      ilog("Joined in parallel mode");
    }

    mark_irreversible_data_as_dirty( false );
  }

  template<bool sequential_mode>
  void reindex_data_dumper<sequential_mode>::mark_irreversible_data_as_dirty( bool is_dirty ) {
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
