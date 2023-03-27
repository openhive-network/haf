#include "pq_utils/copy_session.hpp"

#include "psql_utils/postgres_includes.hpp"
#include "include/exceptions.hpp"


#include <cassert>
#include <exception>
#include <limits>

using namespace std::string_literals;

namespace PsqlTools::PostgresPQ {

CopySession::CopySession( std::shared_ptr< PGconn > _connection, const std::string& _table_name, const std::vector< std::string >& _columns )
  : m_connection( std::move(_connection) )
  , m_table_name( _table_name ) {
  if ( m_connection  == nullptr ) {
    THROW_INITIALIZATION_ERROR( "No connection to postgres" );
  }

  if ( _table_name.empty() ) {
    THROW_INITIALIZATION_ERROR( "Incorrect table name "s + _table_name  );
  }

  std::string binary_copy_cmd = "COPY " + _table_name;
  if ( !_columns.empty() ) {
    std::string columns_list;
    for (auto &column : _columns) {
      if ( !columns_list.empty() ) {
        columns_list.push_back(',');
      }
      columns_list.append( column );
    }
    binary_copy_cmd.append( "("s + columns_list + ")"s );
  }
  binary_copy_cmd.append( " FROM STDIN binary" );
  std::shared_ptr< PGresult > open_session_result( PQexec( m_connection.get(), binary_copy_cmd.c_str() ), PQclear );

  if ( PQresultStatus( open_session_result.get() ) != PGRES_COPY_IN ) {
    auto pg_error_msg = PQerrorMessage( m_connection.get() );
    THROW_INITIALIZATION_ERROR( "Cannot start copy to table: " + _table_name + " :"s + pg_error_msg );
  }
}

CopySession::~CopySession() {
  assert( m_connection );
  PQputCopyEnd( m_connection.get(), nullptr );
}

std::string
CopySession::get_table_name() const {
  return m_table_name;
}

void
CopySession::push_data_internal( const char* _data, uint32_t _size ) const {
  assert( m_connection );

  if ( _size > std::numeric_limits< int32_t >::max() ) {
    THROW_RUNTIME_ERROR( "To much bytes to copy into table "s + m_table_name );
  }

  static constexpr auto COPY_SUCCESS = 1;
  const auto copy_result = PQputCopyData( m_connection.get(), const_cast< char* >( _data ), static_cast<int32_t>( _size ) );

  if ( copy_result != COPY_SUCCESS ) {
    THROW_RUNTIME_ERROR( "Cannot COPY data to table "s + m_table_name + " :" + PQerrorMessage( m_connection.get() ) );
  }
}

} // namespace PsqlTools::PostgresPQ

