#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <hive/plugins/sql_serializer/indexes_interruptor.h>

namespace appbase
{
  class application;
}

namespace hive::plugins::sql_serializer {
  class queries_commit_data_processor;

  // Which indexes of the irreversible tables a massive sync drops (psql-massive-index-policy)
  enum class massive_index_policy
  {
    drop_all,       // every index and PK/UNIQUE constraint
    keep_monotonic  // only those classified 'defer' in hafd.indexes_constraints.massive_sync_class
  };

  // Accepts the option values "drop-all" and "keep-monotonic"; throws std::invalid_argument otherwise.
  massive_index_policy parse_massive_index_policy( const std::string& name );
  const char* to_string( massive_index_policy policy );

  class indexes_controler{
  public:
    indexes_controler( std::string db_url, uint32_t psql_index_threshold, uint32_t monitor_retry_budget_seconds, massive_index_policy index_policy, appbase::application& app );
    void disable_indexes_depends_on_blocks( uint32_t number_of_blocks_to_insert );
    void enable_indexes();
    bool disable_constraints( uint32_t number_of_blocks_to_insert );
    void enable_constrains();
    void poll_and_create_indexes();

  private:
    std::unique_ptr<queries_commit_data_processor>
    start_commit_sql( bool mode, const std::string& sql_function_call, std::string objects_name );

    bool are_any_indexes_missing() const;
    void vacuum_account_operations();
  private:
    const std::string _db_url;
    const uint32_t _psql_index_threshold;
    const uint32_t _monitor_retry_budget_seconds;
    const massive_index_policy _index_policy;
    indexes_interruptor _interruptor;
    appbase::application& theApp;
  };

} //namespace hive::plugins::sql_serializer
