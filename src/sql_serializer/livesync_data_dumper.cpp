#include <hive/plugins/sql_serializer/livesync_data_dumper.h>
#include <transactions_controller/transaction_controllers.hpp>

#include <hive/chain/database.hpp>

namespace hive{ namespace plugins{ namespace sql_serializer {
  livesync_data_dumper::livesync_data_dumper(
      const std::string& db_url
    , const appbase::abstract_plugin& plugin
    , hive::chain::database& chain_db
    ) {
    auto blocks_callback = [this]( std::string&& _text ){
      _block = std::move( _text );
    };

    auto transactions_callback = [this]( std::string&& _text ){
      _transactions = std::move( _text );
    };

    auto transactions_multisig_callback = [this]( std::string&& _text ){
      _transactions_multisig = std::move( _text );
    };

    auto operations_callback = [this]( std::string&& _text ){
      _operations = std::move( _text );
    };

    auto accounts_callback = [this]( std::string&& _text ){
      _accounts = std::move( _text );
    };

    auto account_operations_callback = [this]( std::string&& _text ){
      _account_operations = std::move( _text );
    };

    transactions_controller = transaction_controllers::build_own_transaction_controller( db_url, "Livesync dumper" );
    constexpr auto NUMBER_OF_PROCESSORS_THREADS = 6;
    auto execute_push_block = [this](block_num_rendezvous_trigger::BLOCK_NUM _block_num ){
      if ( !_block.empty() ) {
        auto transaction = transactions_controller->openTx();

        std::string block_to_dump = _block + "::hive.blocks";
        std::string transactions_to_dump = "ARRAY[" + std::move( _transactions ) + "]::hive.transactions[]";
        std::string signatures_to_dump = "ARRAY[" + std::move( _transactions_multisig ) + "]::hive.transactions_multisig[]";
        std::string operations_to_dump = "ARRAY[" + std::move( _operations ) + "]::hive.operations[]";
        std::string accounts_to_dump = "ARRAY[" + std::move( _accounts ) + "]::hive.accounts[]";
        std::string account_operations_to_dump = "ARRAY[" + std::move( _account_operations ) + "]::hive.account_operations[]";

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
      _block.clear(); _transactions.clear(); _transactions_multisig.clear(); _operations.clear();
    };
    auto api_trigger = std::make_shared< block_num_rendezvous_trigger >( NUMBER_OF_PROCESSORS_THREADS, execute_push_block );

    _block_writer = std::make_unique<block_data_container_t_writer>(blocks_callback, "Block data writer", api_trigger);
    _transaction_writer = std::make_unique<transaction_data_container_t_writer>(transactions_callback, "Transaction data writer", api_trigger);
    _transaction_multisig_writer = std::make_unique<transaction_multisig_data_container_t_writer>(transactions_multisig_callback, "Transaction multisig data writer", api_trigger);
    _operation_writer = std::make_unique<operation_data_container_t_writer>(operations_callback, "Operation data writer", api_trigger);
    _account_writer = std::make_unique<accounts_data_container_t_writer>(accounts_callback, "Accounts data writer", api_trigger);
    _account_operations_writer = std::make_unique< account_operations_data_container_t_writer >(account_operations_callback, "Account operations data writer", api_trigger);

    _on_irreversible_block_conn = chain_db.add_irreversible_block_handler(
      [this]( uint32_t block_num ){ on_irreversible_block( block_num ); }
      , plugin
    );

    _on_switch_fork_conn = chain_db.add_switch_fork_handler(
      [this]( uint32_t block_num ){ on_switch_fork( block_num ); }
      , plugin
    );
    ilog( "livesync dumper created" );
  }

  livesync_data_dumper::~livesync_data_dumper() {
    ilog( "livesync dumper is closing..." );
    _on_irreversible_block_conn.disconnect();
    _on_switch_fork_conn.disconnect();
    livesync_data_dumper::join();
    ilog( "livesync dumper closed" );
  }

  void livesync_data_dumper::trigger_data_flush( cached_data_t& cached_data, int last_block_num ) {
    _block_writer->trigger( std::move( cached_data.blocks ), false, last_block_num );
    _operation_writer->trigger( std::move( cached_data.operations ), false, last_block_num );
    _transaction_writer->trigger( std::move( cached_data.transactions ), false, last_block_num);
    _transaction_multisig_writer->trigger( std::move( cached_data.transactions_multisig ), false, last_block_num );
    _account_writer->trigger( std::move( cached_data.accounts ), false, last_block_num );
    _account_operations_writer->trigger( std::move( cached_data.account_operations ), false, last_block_num );

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
    );
  }

  void livesync_data_dumper::wait_for_data_processing_finish()
  {
    _block_writer->complete_data_processing();
    _transaction_writer->complete_data_processing();
    _transaction_multisig_writer->complete_data_processing();
    _operation_writer->complete_data_processing();
    _account_writer->complete_data_processing();
    _account_operations_writer->complete_data_processing();
  }

  void livesync_data_dumper::on_irreversible_block( uint32_t block_num ) {
    auto transaction = transactions_controller->openTx();
    std::string command = "SELECT hive.set_irreversible(" + std::to_string(block_num) + ")";
    transaction->exec( command );
    transaction->commit();
  }

  void livesync_data_dumper::on_switch_fork( uint32_t block_num ) {
    auto transaction = transactions_controller->openTx();
    std::string command = "SELECT hive.back_from_fork(" + std::to_string(block_num) + ")";
    transaction->exec( command );
    transaction->commit();
  }
}}} // namespace hive::plugins::sql_serializer


