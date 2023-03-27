#include "pq_utils/db_client.hpp"

#include "include/exceptions.hpp"
#include "psql_utils/postgres_includes.hpp"
#include "psql_utils/logger.hpp"
#include "pq_utils/transaction.hpp"

#include <exception>
#include <cassert>

namespace PsqlTools::PostgresPQ {

DbClient::DbClient( const std::string& _db_name ) {
  if ( _db_name.empty() ) {
    THROW_INITIALIZATION_ERROR( "Incorrect database name" );
  }
  // Because we use PQ only from postgress triggers/function we don't have to pass user and password
  std::string connection_string = "dbname=" + _db_name;
  m_connection.reset( PQconnectdb( connection_string.c_str() ), PQfinish );

  if ( m_connection == nullptr ) {
    THROW_INITIALIZATION_ERROR( "Cannot connect to databse '" + _db_name + "'" );
  }

  if ( !isConnected() )
  {
    std::string error = "Failed connection to database " + _db_name + " : " + PQerrorMessage(m_connection.get());
    m_connection.reset();
    THROW_INITIALIZATION_ERROR( error );
  }
}

DbClient::DbClient():DbClient(getCurrentDatabaseName() ) {
}

std::unique_ptr< Transaction >
DbClient::startTransaction() {
  return std::make_unique< Transaction >( m_connection );
}

DbClient::~DbClient() {
}

bool
DbClient::isConnected() const {
  return PQstatus( m_connection.get() ) == CONNECTION_OK;
}

DbClient&
DbClient::currentDatabase(){
  // Don't care for the lifetime, it will be released together with whole psql client connection process
  if ( !ms_instance ) {
    ms_instance.reset(new DbClient());
  }

  /* If the PQclient has been disconected by the server, then we try to re-establish the connection once
   * If the connection is still not valid then the client methods will fail and throw exceptions which become visible on postgres log and consele
   * Each new trigger/function will try again to re-establish the connection
   */
  if ( !ms_instance->isConnected() ) {
    LOG_WARNING( "PQclient was disconnected from the server and try to reconnect" );
    ms_instance.reset( new DbClient() );
  }

  return *ms_instance;
}

std::string
DbClient::getCurrentDatabaseName() const {
  Datum db_name = OidFunctionCall0( F_CURRENT_DATABASE );
  return DatumGetCString( db_name );
}

std::unique_ptr< DbClient > DbClient::ms_instance;

} // namespace PsqlTools::PostgresPQ


