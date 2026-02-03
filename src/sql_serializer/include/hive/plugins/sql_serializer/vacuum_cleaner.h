#pragma once

#include <cstdint>
#include <string>

namespace hive { namespace plugins { namespace sql_serializer {

class vacuum_cleaner
{
public:
  explicit vacuum_cleaner( std::string db_url );

  void vacuum( bool is_pruning_enabled, uint32_t block_num );

private:
  void execute_vacuum_commands( const std::string& query );

  std::string _db_url;
};

} } } // namespace hive::plugins::sql_serializer
