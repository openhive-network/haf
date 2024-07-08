#include <hive/plugins/sql_serializer/livesync_data_dumper.h>
#include <transactions_controller/transaction_controllers.hpp>

#include <hive/chain/database.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  livesync_data_dumper::livesync_data_dumper(
      const std::string& db_url
    , const appbase::abstract_plugin& plugin
    , hive::chain::database& chain_db
    , appbase::application& app
    , uint32_t operations_threads
    , uint32_t transactions_threads
    , uint32_t account_operation_threads
    , uint32_t psql_first_block
    , write_ahead_log_manager& write_ahead_log
    )
  : _plugin( plugin )
  , _chain_db( chain_db )
  , app(app)
  , transactions_controller(transaction_controllers::build_own_transaction_controller(db_url, "Livesync dumper", app, true /*sync_commits*/))
  , _psql_first_block( psql_first_block )
  , _write_ahead_log(write_ahead_log)
  , _processing_thread(transactions_controller, write_ahead_log, app)
  {
    auto blocks_callback = [this]( std::string&& _text ){
      _block = std::move( _text );
    };

    auto transactions_multisig_callback = [this]( std::string&& _text ){
      _transactions_multisig = std::move( _text );
    };

    auto accounts_callback = [this]( std::string&& _text ){
      _accounts = std::move( _text );
    };

    auto applied_hardforks_callback = [this]( std::string&& _text ){
      _applied_hardforks = std::move( _text );
    };

    constexpr auto ONE_THREAD_WRITERS_NUMBER = 4;
    auto NUMBER_OF_PROCESSORS_THREADS = ONE_THREAD_WRITERS_NUMBER + operations_threads + transactions_threads + account_operation_threads;
    auto execute_push_block = [this](block_num_rendezvous_trigger::BLOCK_NUM _block_num ){
      if ( !_block.empty() ) {
        std::string block_to_dump = _block + "::hive.blocks";
        std::string transactions_to_dump = "ARRAY[" + _transaction_writer->get_merged_strings() + "]::hive.transactions[]";
        std::string signatures_to_dump = "ARRAY[" + std::move( _transactions_multisig ) + "]::hive.transactions_multisig[]";
        std::string operations_to_dump = "ARRAY[" + _operation_writer->get_merged_strings() + "]::hive.operations[]";
        std::string accounts_to_dump = "ARRAY[" + std::move( _accounts ) + "]::hive.accounts[]";
        std::string account_operations_to_dump = "ARRAY[" + _account_operations_writer->get_merged_strings() + "]::hive.account_operations[]";
        std::string applied_hardforks_to_dump = "ARRAY[" + std::move( _applied_hardforks ) + "]::hive.applied_hardforks[]";

        std::string sql_command = "SELECT hive.push_block(" +
                block_to_dump +
          "," + transactions_to_dump +
          "," + signatures_to_dump +
          "," + operations_to_dump +
          "," + accounts_to_dump +
          "," + account_operations_to_dump +
          "," + applied_hardforks_to_dump +
          ")";

        _processing_thread.enqueue(std::move(sql_command));
      }
      _block.clear();
      _transactions_multisig.clear();
      _accounts.clear();
      _applied_hardforks.clear();
    };
    auto api_trigger = std::make_shared< block_num_rendezvous_trigger >( NUMBER_OF_PROCESSORS_THREADS, execute_push_block );

    _block_writer = std::make_unique<block_data_container_t_writer>(blocks_callback, "Block data writer", "block", api_trigger, app);
    _transaction_writer = std::make_unique<transaction_data_container_t_writer>(transactions_threads, "Transaction data writer", "trx", api_trigger, app);
    _transaction_multisig_writer = std::make_unique<transaction_multisig_data_container_t_writer>(transactions_multisig_callback, "Transaction multisig data writer", "trx_multi", api_trigger, app);
    _operation_writer = std::make_unique<operation_data_container_t_writer>(operations_threads, "Operation data writer", "op", api_trigger, app);
    _account_writer = std::make_unique<accounts_data_container_t_writer>(accounts_callback, "Accounts data writer", "account", api_trigger, app);
    _account_operations_writer = std::make_unique< account_operations_data_container_t_writer >(account_operation_threads, "Account operations data writer", "account_op", api_trigger, app);
    _applied_hardforks_writer = std::make_unique< applied_hardforks_container_t_writer >(applied_hardforks_callback,"Applied hardforks data writer", "hardfork", api_trigger, app);

    connect_irreversible_event();
    connect_fork_event();

    ilog( "livesync dumper created" );
  }

  livesync_data_dumper::~livesync_data_dumper() {
    ilog( "livesync dumper is closing..." );
    disconnect_irreversible_event();
    disconnect_fork_event();
    try {
      join();
    } FC_CAPTURE_AND_LOG(())
    ilog( "livesync dumper closed" );
  }

  void livesync_data_dumper::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
    FC_ASSERT( cached_data.blocks.size() == 1, "LIVE sync can only process one block" );
    if (app.is_interrupt_request())
    {
      cancel();
      return;
    }
    _block_writer->trigger( std::move( cached_data.blocks ), last_block_num );
    _operation_writer->trigger( std::move( cached_data.operations ), last_block_num );
    _transaction_writer->trigger( std::move( cached_data.transactions ), last_block_num);
    _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), last_block_num );
    _account_writer->trigger( std::move( cached_data.accounts ), last_block_num );
    _account_operations_writer->trigger( std::move( cached_data.account_operations ), last_block_num );
    _applied_hardforks_writer->trigger( std::move(cached_data.applied_hardforks ), last_block_num );

    _block_writer->complete_data_processing();
    _operation_writer->complete_data_processing();
    _transaction_writer->complete_data_processing();
    _transaction_multisig_writer->complete_data_processing();
    _account_writer->complete_data_processing();
    _account_operations_writer->complete_data_processing();
    _applied_hardforks_writer->complete_data_processing();
  }

  void livesync_data_dumper::cancel() {
    cancel_processors(
      *_block_writer,
      *_transaction_writer,
      *_operation_writer,
      *_transaction_multisig_writer,
      *_account_writer,
      *_account_operations_writer,
      *_applied_hardforks_writer
    );
  }

  void livesync_data_dumper::join() {
    join_processors(
        *_block_writer
      , *_transaction_writer
      , *_transaction_multisig_writer
      , *_operation_writer
      , *_account_writer
      , *_account_operations_writer
      , *_applied_hardforks_writer
    );
  }

  void livesync_data_dumper::on_irreversible_block( uint32_t block_num ) {
    // if sync has started not from first block (option psql-first-block), then
    // it may happen that we got irreversible block
    // event for blocks which are not dumped to the database
    if ( block_num >= _psql_first_block )
    {
      _processing_thread.enqueue("SELECT hive.set_irreversible(" + std::to_string(block_num) + ")");
      _processing_thread.enqueue("SET ROLE hived_group; CALL hive.proc_perform_dead_app_contexts_auto_detach();");
    }
  }

  void livesync_data_dumper::on_switch_fork( uint32_t block_num ) {
      _processing_thread.enqueue("SELECT hive.back_from_fork(" + std::to_string(block_num) + ")");
  }

  void livesync_data_dumper::connect_irreversible_event() {
    if ( _on_irreversible_block_conn.connected() ) {
      return;
    }

    _on_irreversible_block_conn = _chain_db.add_irreversible_block_handler(
      [this]( uint32_t block_num ){ on_irreversible_block( block_num ); }
      , _plugin
      );
  }

  void livesync_data_dumper::disconnect_irreversible_event() {
    _on_irreversible_block_conn.disconnect();
  }

  void livesync_data_dumper::connect_fork_event() {
    if ( _on_switch_fork_conn.connected() ) {
      return;
    }

    _on_switch_fork_conn = _chain_db.add_switch_fork_handler(
      [this]( uint32_t block_num ){ on_switch_fork( block_num ); }
      , _plugin
    );
  }

  void livesync_data_dumper::disconnect_fork_event() {
    _on_switch_fork_conn.disconnect();
  }

  livesync_data_dumper::processing_thread::processing_thread(std::shared_ptr<transaction_controllers::transaction_controller> transactions_controller,
                                                             write_ahead_log_manager& write_ahead_log,
                                                             appbase::application& app) :
    _transactions_controller(transactions_controller),
    _write_ahead_log(write_ahead_log),
    _app(app)
  {
    _future = std::async([this]() { run(); });
  }

  livesync_data_dumper::processing_thread::~processing_thread()
  {
    ilog("Calling wal thread shutdown");
    shutdown();
    ilog("Waiting for wal thread future");
    _future.wait();
    ilog("exiting destructor");
  }

  void livesync_data_dumper::processing_thread::run()
  {
    fc::set_thread_name("sql[wal proc]");
    fc::thread::current().set_name("sql[wal proc]");
    ilog("Starting hived->postgresql write-ahead log processing thread");
    BOOST_SCOPE_EXIT(void) { ilog("Exiting hived->postgresql write-ahead log processing thread"); } BOOST_SCOPE_EXIT_END
    for (;;)
    {
      // dequeue the next command into command_to_run, waiting if the queue is empty
      sql_command_with_sequence_t command_to_run;
      unsigned commands_remaining;
      {
        std::unique_lock<std::mutex> lock(_mutex);
        _condition_variable.wait(lock, [&](){ return _shutdown_requested || !_command_queue.empty(); });
        // if shutdown is requested, continue processing the queue until it's empty, then exit.
        // an earlier version had this condition: if (_shutdown_requested), which made for a quicker shutdown
        if (_command_queue.empty())
        {
          ilog("Terminating hived->postgresql write-ahead log processing because shutdown was requested");
          break;
        }
        else if (_shutdown_requested)
          ilog("Dumping wal as part of shutdown");

        command_to_run = std::move(_command_queue.front());
        _command_queue.pop_front();
        commands_remaining = _command_queue.size();
      }
      _condition_variable.notify_one();
      dlog("processing thread is working on transaction with sequence number ${seq}, ${commands_remaining} remaining in queue", ("seq", command_to_run.first)(commands_remaining));

      // execute the command
      try
      {
        auto transaction = _transactions_controller->openTx();
        transaction->exec(command_to_run.second);
        transaction->exec("SELECT hive.update_wal_sequence_number(" + std::to_string(command_to_run.first) + ")");
        transaction->commit();
      }
      catch (const pqxx::failure& ex)
      {
        elog("Write-ahead log processor detected SQL error: ${what}", ("what", ex.what()));
        _app.kill();
        throw;
      }
      catch (const fc::exception& ex)
      {
        elog("Write-ahead log processor detected error: ${ex}", (ex));
        _app.kill();
        throw;
      }
      catch (const std::exception& ex)
      {
        elog("Write-ahead log processor detected error: ${what}", ("what", ex.what()));
        _app.kill();
        throw;
      }
      catch (...)
      {
        elog("Write-ahead log processor detected unknown error");
        _app.kill();
        throw;
      }

      // notify the WAL that we've completed it
      _write_ahead_log.transaction_completed(command_to_run.first);
    }
  }

  void livesync_data_dumper::processing_thread::enqueue(std::string&& sql_command)
  {
    if (_write_ahead_log.is_open())
    {
      // first, write it to the write ahead log and flush to disk
      write_ahead_log_manager::sequence_number_t sequence_number = _write_ahead_log.store_transaction(sql_command);

      // now we can add it to the queue and let it be processed later
      {
        std::unique_lock<std::mutex> lock(_mutex);
        _condition_variable.wait(lock, [&](){ return _command_queue.size() < _max_queue_depth; });
        _command_queue.emplace_back(sequence_number, sql_command);
      }
      _condition_variable.notify_one();
    }
    else
    {
      // no reason to jump threads, just process the sql command here
      auto transaction = _transactions_controller->openTx();
      transaction->exec(sql_command);
      transaction->commit();
    }
  }

  void livesync_data_dumper::processing_thread::shutdown()
  {
    {
      std::unique_lock<std::mutex> lock(_mutex);
      _shutdown_requested = true;
    }
    ilog("notify condition_variable for shutdown");
    _condition_variable.notify_one();
  }

}}} // namespace hive::plugins::sql_serializer


