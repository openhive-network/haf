#include <hive/plugins/sql_serializer/livesync_data_dumper.h>
#include <transactions_controller/transaction_controllers.hpp>

#include <hive/chain/database.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {

  livesync_data_dumper::livesync_data_dumper(
      const std::string& db_url
    , const appbase::abstract_plugin& plugin
    , hive::chain::database& chain_db
    , uint32_t operations_threads
    , uint32_t transactions_threads
    , uint32_t account_operation_threads
    )
  : _plugin( plugin )
  , _chain_db( chain_db )
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

    transactions_controller = transaction_controllers::build_own_transaction_controller( db_url, "Livesync dumper" );
    constexpr auto ONE_THREAD_WRITERS_NUMBER = 3;
    auto NUMBER_OF_PROCESSORS_THREADS = ONE_THREAD_WRITERS_NUMBER + operations_threads + transactions_threads + account_operation_threads;
    auto execute_push_block = [this](block_num_rendezvous_trigger::BLOCK_NUM _block_num ){
      if ( !_block.empty() ) {
        auto transaction = transactions_controller->openTx();

        std::string block_to_dump = _block + "::hive.blocks";
        std::string transactions_to_dump = "ARRAY[" + _transaction_writer->get_merged_strings() + "]::hive.transactions[]";
        std::string signatures_to_dump = "ARRAY[" + std::move( _transactions_multisig ) + "]::hive.transactions_multisig[]";
        std::string operations_to_dump = "ARRAY[" + _operation_writer->get_merged_strings() + "]::hive.operations[]";
        std::string accounts_to_dump = "ARRAY[" + std::move( _accounts ) + "]::hive.accounts[]";
        std::string account_operations_to_dump = "ARRAY[" + _account_operations_writer->get_merged_strings() + "]::hive.account_operations[]";

        std::string sql_command = "SELECT hive.push_block(" +
                block_to_dump +
          "," + transactions_to_dump +
          "," + signatures_to_dump +
          "," + operations_to_dump +
          "," + accounts_to_dump +
          "," + account_operations_to_dump +
          ")";

        transaction->exec( sql_command );
        transaction->commit();
      }
      _block.clear();
      _transactions_multisig.clear();
      _accounts.clear();
    };
    auto api_trigger = std::make_shared< block_num_rendezvous_trigger >( NUMBER_OF_PROCESSORS_THREADS, execute_push_block );

    _block_writer = std::make_unique<block_data_container_t_writer>(blocks_callback, "Block data writer", api_trigger);
    _transaction_writer = std::make_unique<transaction_data_container_t_writer>(transactions_threads, "Transaction data writer", api_trigger);
    _transaction_multisig_writer = std::make_unique<transaction_multisig_data_container_t_writer>(transactions_multisig_callback, "Transaction multisig data writer", api_trigger);
    _operation_writer = std::make_unique<operation_data_container_t_writer>(operations_threads, "Operation data writer", api_trigger );
    _account_writer = std::make_unique<accounts_data_container_t_writer>(accounts_callback, "Accounts data writer", api_trigger);
    _account_operations_writer = std::make_unique< account_operations_data_container_t_writer >(account_operation_threads, "Account operations data writer", api_trigger);

    auto execute_set_irreversible
      = [&](const data_processor::data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx)->data_processor::data_processing_status{
      std::string command = "SELECT hive.set_irreversible(" + std::to_string( _irreversible_block_num ) + ")";
      tx.exec( command );
      return data_processor::data_processing_status();
    };
    _set_irreversible_block_processor = std::make_unique< queries_commit_data_processor >( db_url, "hive.set_irreversible caller", execute_set_irreversible, nullptr );

    auto execute_back_from_fork
    = [&](const data_processor::data_chunk_ptr& dataPtr, transaction_controllers::transaction& tx)->data_processor::data_processing_status{
      std::string command = "SELECT hive.back_from_fork(" + std::to_string( _last_fork_block_num ) + ")";
      tx.exec( command );
      return data_processor::data_processing_status();
    };
    _notify_fork_block_processor = std::make_unique< queries_commit_data_processor >( db_url, "hive.back_from_fork caller", execute_back_from_fork, nullptr );

    connect_irreversible_event();
    connect_fork_event();

    ilog( "livesync dumper created" );
  }

  livesync_data_dumper::~livesync_data_dumper() {
    ilog( "livesync dumper is closing..." );
    disconnect_irreversible_event();
    disconnect_fork_event();
    livesync_data_dumper::join();
    ilog( "livesync dumper closed" );
  }

  void livesync_data_dumper::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
    FC_ASSERT( cached_data.blocks.size() == 1, "LIVE sync can only process one block" );
    _block_writer->trigger( std::move( cached_data.blocks ), last_block_num );
    _operation_writer->trigger( std::move( cached_data.operations ), last_block_num );
    _transaction_writer->trigger( std::move( cached_data.transactions ), last_block_num);
    _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), last_block_num );
    _account_writer->trigger( std::move( cached_data.accounts ), last_block_num );
    _account_operations_writer->trigger( std::move( cached_data.account_operations ), last_block_num );

    _block_writer->complete_data_processing();
    _operation_writer->complete_data_processing();
    _transaction_writer->complete_data_processing();
    _transaction_multisig_writer->complete_data_processing();
    _account_writer->complete_data_processing();
    _account_operations_writer->complete_data_processing();
  }

  void livesync_data_dumper::join() {
    join_writers(
        *_block_writer
      , *_transaction_writer
      , *_transaction_multisig_writer
      , *_operation_writer
      , *_account_writer
      , *_account_operations_writer
      , *_set_irreversible_block_processor
      , *_notify_fork_block_processor
    );
  }

  void livesync_data_dumper::on_irreversible_block( uint32_t block_num ) {
    _irreversible_block_num = block_num;
    constexpr auto NUMBER_WITHOUT_MEANING = 0;
    _set_irreversible_block_processor->trigger( nullptr, NUMBER_WITHOUT_MEANING );
    _set_irreversible_block_processor->complete_data_processing();
  }

  void livesync_data_dumper::on_switch_fork( uint32_t block_num ) {
    _last_fork_block_num = block_num;
    constexpr auto NUMBER_WITHOUT_MEANING = 0;
    _notify_fork_block_processor->trigger( nullptr, NUMBER_WITHOUT_MEANING );
    _notify_fork_block_processor->complete_data_processing();
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
}}} // namespace hive::plugins::sql_serializer


