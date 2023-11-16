#pragma once

#include <hive/plugins/sql_serializer/data_dumper.h>

#include <hive/plugins/sql_serializer/table_data_writer.h>
#include <hive/plugins/sql_serializer/tables_descriptions.h>
#include <hive/plugins/sql_serializer/chunks_for_writers_spillter.h>

#include <hive/plugins/sql_serializer/end_massive_sync_processor.hpp>
#include <hive/plugins/sql_serializer/cached_data.h>

#include <memory>
#include <string>

namespace hive::plugins::sql_serializer {

  class reindex_data_dumper: public data_dumper {
  public:
    reindex_data_dumper(
        const std::string& db_url
      , appbase::application& app
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

    using block_data_container_t_writer = table_data_writer<hive_blocks>;
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

    using applied_hardforks_container_t_writer = table_data_writer< hive_applied_hardforks >;

    using accounts_data_container_t_writer = table_data_writer<
      hive_accounts<
        std::vector<PSQL::processing_objects::account_data_t>
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
    std::unique_ptr< applied_hardforks_container_t_writer > _applied_hardforks_writer;

    std::unique_ptr<end_massive_sync_processor> _end_massive_sync_processor;
    std::shared_ptr< transaction_controllers::transaction_controller > _transactions_controller;
  };

} // namespace hive::plugins::sql_serializer
