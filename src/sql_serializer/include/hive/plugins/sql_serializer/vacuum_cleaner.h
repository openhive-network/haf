#pragma once

#include <cstdint>
#include <string>

#include <pqxx/pqxx>

namespace hive { namespace plugins { namespace sql_serializer {

/**
 * Runs a VACUUM/ANALYZE command, giving up when a lock on its table is not granted within a second.
 * Returns false when it gave up; the table is then left as it was. Other errors are thrown.
 * Leaves the session's lock_timeout at its default.
 */
bool vacuum_unless_locked( pqxx::nontransaction& tx, const std::string& vacuum_command );

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
