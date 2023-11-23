#pragma once

#include <hive/plugins/sql_serializer/data_dumper.h>

#include <hive/plugins/sql_serializer/table_data_writer.h>
#include <hive/plugins/sql_serializer/tables_descriptions.h>
#include <hive/plugins/sql_serializer/string_data_processor.h>
#include <hive/plugins/sql_serializer/chunks_for_writers_spillter.h>

#include <hive/plugins/sql_serializer/cached_data.h>

#include <boost/signals2.hpp>

#include <functional>
#include <memory>
#include <string>

namespace appbase { class abstract_plugin; }

namespace hive::chain {
  class database;
} // namespace hive::chain

namespace hive::plugins::sql_serializer {
  class transaction_controller;

  class livesync_data_dumper : public data_dumper {
  public:
    livesync_data_dumper(
        const std::string& db_url
      , const appbase::abstract_plugin& plugin
      , hive::chain::database& chain_db
      , appbase::application& app
      , uint32_t operations_threads
      , uint32_t transactions_threads
      , uint32_t account_operation_threads
      , uint32_t start_block_num
    );

    ~livesync_data_dumper();
    livesync_data_dumper(livesync_data_dumper&) = delete;
    livesync_data_dumper(livesync_data_dumper&&) = delete;
    livesync_data_dumper& operator=(livesync_data_dumper&&) = delete;
    livesync_data_dumper& operator=(livesync_data_dumper&) = delete;

    void trigger_data_flush( cached_data_t& cached_data, int last_block_num ) override;

  private:
    void connect_irreversible_event();
    void disconnect_irreversible_event();
    void connect_fork_event();
    void disconnect_fork_event();

    transaction_controllers::transaction_controller& get_transaction_controller() { return *transactions_controller; };

    void join();
    void on_irreversible_block( uint32_t block_num );
    void on_switch_fork( uint32_t block_num );

  private:
    using block_data_container_t_writer = table_data_writer<hive_blocks, string_data_processor>;

    using transaction_data_container_t_writer = chunks_for_string_writers_splitter<
      table_data_writer<
            hive_transactions< container_view< std::vector<PSQL::processing_objects::process_transaction_t> > >
          , string_data_processor
      >
    >;

    using transaction_multisig_data_container_t_writer = table_data_writer<hive_transactions_multisig, string_data_processor>;
    using operation_data_container_t_writer = chunks_for_string_writers_splitter<
        table_data_writer<
              hive_operations< container_view< std::vector<PSQL::processing_objects::process_operation_t> > >
            , string_data_processor
        >
      >;

    using applied_hardforks_container_t_writer = table_data_writer<hive_applied_hardforks, string_data_processor>;

    using accounts_data_container_t_writer = table_data_writer<
        hive_accounts< std::vector<PSQL::processing_objects::account_data_t> >
      , string_data_processor
    >;
    using account_operations_data_container_t_writer = chunks_for_string_writers_splitter<
        table_data_writer<
            hive_account_operations< container_view< std::vector<PSQL::processing_objects::account_operation_data_t> > >
          , string_data_processor
        >
      >;

    const appbase::abstract_plugin& _plugin;
    hive::chain::database& _chain_db;

    std::unique_ptr< block_data_container_t_writer > _block_writer;
    std::unique_ptr< transaction_data_container_t_writer > _transaction_writer;
    std::unique_ptr< transaction_multisig_data_container_t_writer > _transaction_multisig_writer;
    std::unique_ptr< operation_data_container_t_writer > _operation_writer;
    std::unique_ptr< accounts_data_container_t_writer > _account_writer;
    std::unique_ptr< account_operations_data_container_t_writer > _account_operations_writer;
    std::unique_ptr< applied_hardforks_container_t_writer > _applied_hardforks_writer;

    std::unique_ptr< queries_commit_data_processor > _set_irreversible_block_processor;
    std::unique_ptr< queries_commit_data_processor > _notify_fork_block_processor;

    std::string _block;
    std::string _transactions_multisig;
    std::string _accounts;
    std::string _applied_hardforks;

    boost::signals2::connection _on_irreversible_block_conn;
    boost::signals2::connection _on_switch_fork_conn;
    std::shared_ptr< transaction_controllers::transaction_controller > transactions_controller;

    uint32_t _irreversible_block_num = 0;
    uint32_t _last_fork_block_num = 0;

    const uint32_t _psql_first_block;

  };

} // namespace hive::plugins::sql_serializer
