#include "pq_utils/transaction.hpp"

#include "pq_utils/copy_tuples_session.hpp"

#include "include/exceptions.hpp"
#include "psql_utils/logger.hpp"
#include "psql_utils/postgres_includes.hpp"

#include <cassert>
#include <string>

using namespace std::string_literals;

namespace PsqlTools::PostgresPQ {

Transaction::Transaction( std::shared_ptr< PGconn > _connection )
  : m_connection( _connection ) {
    if ( m_connection == nullptr ) {
      THROW_INITIALIZATION_ERROR( "Connection is nullptr" );
    }

    auto result = PQexec( m_connection.get(),  "BEGIN TRANSACTION" );
    if ( PQresultStatus( result ) != PGRES_COMMAND_OK ) {
      THROW_INITIALIZATION_ERROR( "Cannot start transaction :"s + PQresultErrorMessage( result ) );
    }
}

Transaction::~Transaction() {
  assert( m_connection );

  auto result = PQexec( m_connection.get(), "COMMIT" );
  if ( PQresultStatus( result ) != PGRES_COMMAND_OK ) {
    // We cannot throw an exception from d_tor, so it is better to close immediataly the plugin session by log error
    LOG_ERROR( "Cannot commit transaction :%s", PQresultErrorMessage( result ) );
  }
}

void
Transaction::execute( const std::string& _sql ) const {
  auto result = PQexec( m_connection.get(), _sql.c_str() );
  if ( PQresultStatus( result ) != PGRES_COMMAND_OK ) {
    THROW_RUNTIME_ERROR( "Cannot execute sql :"s + _sql + " :"s + PQresultErrorMessage( result ) );
  }
}

std::unique_ptr< CopyTuplesSession >
Transaction::startCopyTuplesSession( const std::string& _table_name, const std::vector< std::string >& _columns ) {
  assert( m_connection );

  return std::make_unique< CopyTuplesSession >( m_connection, _table_name, _columns );
}
} // namespace PsqlTools::PostgresPQ
