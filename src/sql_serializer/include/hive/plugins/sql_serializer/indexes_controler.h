#pragma once

#include <memory>
#include <string>
#include <hive/plugins/sql_serializer/indexes_interruptor.h>

namespace appbase
{
  class application;
}

namespace hive::plugins::sql_serializer {
  class queries_commit_data_processor;

  class indexes_controler{
  public:
    indexes_controler( std::string db_url, uint32_t psql_index_threshold, appbase::application& app );
    void disable_indexes_depends_on_blocks( uint32_t number_of_blocks_to_insert );
    void enable_indexes();
    void disable_constraints();
    void enable_constrains();
    void poll_and_create_indexes();

  private:
    std::unique_ptr<queries_commit_data_processor>
    start_commit_sql( bool mode, const std::string& sql_function_call, std::string objects_name );

    bool are_any_indexes_missing() const;
  private:
    const std::string _db_url;
    const uint32_t _psql_index_threshold;
    indexes_interruptor _interruptor;
    appbase::application& theApp;
  };

} //namespace hive::plugins::sql_serializer
