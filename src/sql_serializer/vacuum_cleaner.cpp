#include <hive/plugins/sql_serializer/vacuum_cleaner.h>

#include <fc/log/logger.hpp>
#include <fc/time.hpp>

#include <pqxx/pqxx>

namespace hive { namespace plugins { namespace sql_serializer {

vacuum_cleaner::vacuum_cleaner( std::string db_url )
  : _db_url( std::move( db_url ) )
{
}

void vacuum_cleaner::vacuum( bool is_pruning_enabled, uint32_t block_num )
{
  if ( is_pruning_enabled && block_num % 500'000 == 0 )
  {
    try
    {
      vacuum_prune();
    }
    catch ( const std::exception& e )
    {
      elog( "Error while checking for prune vacuum requests: ${e}", ( "e", e.what() ) );
      throw;
    }
  }
  else if ( block_num % 100'000 == 0 )
  {
    try
    {
      vacuum_periodic();
    }
    catch ( const std::exception& e )
    {
      elog( "Error while checking for periodic vacuum requests: ${e}", ( "e", e.what() ) );
      throw;
    }
  }
}

void vacuum_cleaner::vacuum_prune()
{
  pqxx::connection conn( _db_url );
  pqxx::nontransaction tx( conn );

  pqxx::result data = tx.exec( "SELECT hive.get_vacuum_full_prune_commands() as vacuum_cmd;" );
  for ( const auto& record : data )
  {
    std::string vacuum_command = record["vacuum_cmd"].as<std::string>();
    auto start_time = fc::time_point::now();
    tx.exec( vacuum_command );
    auto end_time = fc::time_point::now();
    fc::microseconds vacuum_duration = end_time - start_time;
    ilog( "${cmd} in ${duration} ms", ( "cmd", vacuum_command )( "duration", vacuum_duration.count() / 1000 ) );
  }
}

void vacuum_cleaner::vacuum_periodic()
{
  pqxx::connection conn( _db_url );
  pqxx::nontransaction tx( conn );

  pqxx::result data = tx.exec( "SELECT hive.get_vacuum_full_periodic_commands() as vacuum_cmd;" );
  for ( const auto& record : data )
  {
    std::string vacuum_command = record["vacuum_cmd"].as<std::string>();
    auto start_time = fc::time_point::now();
    tx.exec( vacuum_command );
    auto end_time = fc::time_point::now();
    fc::microseconds vacuum_duration = end_time - start_time;
    ilog( "${cmd} in ${duration} ms", ( "cmd", vacuum_command )( "duration", vacuum_duration.count() / 1000 ) );
  }
}

} } } // namespace hive::plugins::sql_serializer
