#include "initializer.hpp"

#include "sql_commands.hpp"

#include "include/exceptions.hpp"
#include "include/psql_utils/postgres_includes.hpp"
#include "include/psql_utils/spi_session.hpp"

#include "gen/git_version.hpp"

#include <string>
#include <unistd.h>

using namespace std::string_literals;

namespace PsqlTools::ForkExtension {
  Initializer::Initializer() try {
    LOG_WARNING( "Initialize hive fork extension ver.: %s pid: %d", GIT_REVISION, getpid() );

    m_spi_session = PsqlTools::PsqlUtils::SpiSession::create();
    initialize_tuples_table();
    initialize_function( BACK_FROM_FORK_FUNCTION, "void" );
    initialize_function( ON_TABLE_CHANGE_FUNCTION, "trigger" );
  }
  catch ( std::exception& _exception ) {
    LOG_ERROR( "Unhandled exception: %s", _exception.what() );
  }
  catch( ... ) {
    LOG_ERROR( "Unhandled unknown exception" );
  }

  void
  Initializer::initialize_tuples_table() const {
    m_spi_session->executeUtil(Sql::CREATE_TUPLES_TABLE);

    LOG_INFO( "The " TUPLES_TABLE_NAME " table is initialized" );
  }

  void
  Initializer::initialize_function( const std::string& _function_name, const std::string& _sql_return_type ) const {
    if ( function_exists( _function_name ) ) {
      LOG_INFO( "The '%s' function already initialized", _function_name.c_str() );
      return;
    }

    const auto execute_cmd
      = "CREATE FUNCTION "s + _function_name + "() RETURNS "s + _sql_return_type + " AS '$libdir/plugins/libfork_extension.so', '"s + _function_name + "' LANGUAGE C"s;

    m_spi_session->executeUtil(execute_cmd);

    LOG_INFO( "The %s function is initialized", _function_name.c_str() );
  }

  bool
  Initializer::function_exists( const std::string& _function_name ) const {
    auto tuples_it = m_spi_session->executeSelect( "SELECT * FROM pg_proc WHERE proname = '" + _function_name + "'" );

    return bool( tuples_it->next() );
  }
} // namespace PsqlTools::ForkExtension
