#include <cstdint>
#include <hive/plugins/sql_serializer/vacuum_cleaner.h>

#include <fc/log/logger.hpp>
#include <fc/time.hpp>

namespace hive { namespace plugins { namespace sql_serializer {

namespace {

const std::string LOCK_NOT_AVAILABLE = "55P03";

} // namespace

// A VACUUM waiting for its lock queues every later session touching the table behind it,
// and applications keep transactions open on the tables hived vacuums.
bool vacuum_unless_locked( pqxx::nontransaction& tx, const std::string& vacuum_command, std::chrono::milliseconds lock_timeout )
{
  tx.exec( "SET lock_timeout = " + std::to_string( lock_timeout.count() ) );
  try
  {
    tx.exec( vacuum_command );
  }
  catch ( const pqxx::sql_error& e )
  {
    tx.exec( "RESET lock_timeout" );
    if ( e.sqlstate() == LOCK_NOT_AVAILABLE )
    {
      wlog( "Skipped ${cmd}: its table stayed locked for ${t} ms; it will be retried later", ( "cmd", vacuum_command )( "t", lock_timeout.count() ) );
      return false;
    }
    throw;
  }
  tx.exec( "RESET lock_timeout" );
  return true;
}

vacuum_cleaner::vacuum_cleaner( std::string db_url )
  : _db_url( std::move( db_url ) )
{
}

void vacuum_cleaner::vacuum( bool is_pruning_enabled, uint32_t block_num )
{
  if ( block_num % 100'000 == 0 )
  {
    try
    {
      execute_vacuum_commands( "SELECT hive.get_vacuum_periodic_commands() as vacuum_cmd;" );
    }
    catch ( const std::exception& e )
    {
      elog( "Error while checking for periodic vacuum requests: ${e}", ( "e", e.what() ) );
      throw;
    }
  }

  // At prune intervals (every 500k blocks), rewrite the pruned tables to return their space.
  if ( is_pruning_enabled && block_num % 500'000 == 0 )
  {
    try
    {
      execute_vacuum_commands( "SELECT hive.get_vacuum_full_prune_commands() as vacuum_cmd;" );
    }
    catch ( const std::exception& e )
    {
      elog( "Error while checking for prune vacuum requests: ${e}", ( "e", e.what() ) );
      throw;
    }
  }
}

void vacuum_cleaner::execute_vacuum_commands( const std::string& query )
{
  pqxx::connection conn( _db_url );
  pqxx::nontransaction tx( conn );

  pqxx::result data = tx.exec( query );
  for ( const auto& record : data )
  {
    std::string vacuum_command = record["vacuum_cmd"].as<std::string>();
    auto start_time = fc::time_point::now();
    if ( !vacuum_unless_locked( tx, vacuum_command ) )
      continue;
    auto end_time = fc::time_point::now();
    fc::microseconds vacuum_duration = end_time - start_time;
    ilog( "${cmd} in ${duration} ms", ( "cmd", vacuum_command )( "duration", vacuum_duration.count() / 1000 ) );
  }
}

} } } // namespace hive::plugins::sql_serializer
