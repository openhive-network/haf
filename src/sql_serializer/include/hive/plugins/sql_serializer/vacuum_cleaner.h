#pragma once

#include <chrono>
#include <cstdint>
#include <string>

#include <pqxx/pqxx>

namespace hive { namespace plugins { namespace sql_serializer {

// How long hived's vacuums wait for their table lock, unless a caller has a reason to wait longer.
constexpr std::chrono::milliseconds VACUUM_LOCK_TIMEOUT{ 1'000 };

/**
 * Runs a VACUUM/ANALYZE command, giving up when a lock on its table is not granted within lock_timeout;
 * a zero lock_timeout waits for the lock without a limit.
 * Returns false when it gave up; the table is then left as it was. Other errors are thrown.
 * Leaves the session's lock_timeout at its default.
 */
bool vacuum_unless_locked( pqxx::nontransaction& tx, const std::string& vacuum_command,
                           std::chrono::milliseconds lock_timeout = VACUUM_LOCK_TIMEOUT );

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
