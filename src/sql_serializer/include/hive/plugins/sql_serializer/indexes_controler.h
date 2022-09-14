#pragma once

#include <memory>
#include <string>

namespace hive::plugins::sql_serializer {
  class queries_commit_data_processor;

  class indexes_controler{
  public:
    indexes_controler( std::string db_url, uint32_t psql_index_threshold );
    void disable_indexes_and_constraints_depends_on_blocks( uint32_t number_of_blocks_to_insert );
    void enable_indexes();
    void disable_constraints();
    void disable_indexes();
    void enable_constrains();

  private:
    std::unique_ptr<queries_commit_data_processor>
    start_commit_sql( bool mode, const std::string& sql_function_call, const std::string& objects_name );

  private:
    const std::string _db_url;
    const uint32_t _psql_index_threshold;
  };

} //namespace hive::plugins::sql_serializer
