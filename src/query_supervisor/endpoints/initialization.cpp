#include "include/psql_utils/postgres_includes.hpp"

#include "postgres_accessor.hpp"

#include "include/psql_utils/backend.h"
#include "include/psql_utils/custom_configuration.h"
#include "include/psql_utils/query_handler/tuples_query_handler.h"
#include "include/psql_utils/spi_session.hpp"

#include <boost/algorithm/string.hpp>
#include <boost/scope_exit.hpp>

#include <chrono>
#include <memory>
#include <vector>

extern "C" {
  PG_MODULE_MAGIC;

bool isCurrentUserLimited() {
  using PsqlTools::QuerySupervisor::PostgresAccessor;
  const auto limitedUsersString = PostgresAccessor::getInstance()
    .getCustomConfiguration().getOptionAsString( "limited_users" );

  LOG_DEBUG( "Limited users: {%s}", limitedUsersString.c_str() );

  if ( limitedUsersString.empty() ) {
    return false;
  }

  std::vector< std::string > users;
  boost::split( users, limitedUsersString, boost::is_any_of(",") );

  auto userIt = std::find( users.begin(), users.end(), PostgresAccessor::getInstance().getBackend().userName() );
  return userIt != users.end();
}

void _PG_init(void) {
  using PsqlTools::QuerySupervisor::PostgresAccessor;

  LOG_INFO( "Loading query_supervisor.so into backend %d...", getpid() );

  BOOST_SCOPE_EXIT(void) {
    LOG_INFO( "query_supervisor.so loaded into backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  if ( !isCurrentUserLimited() ) {
    LOG_DEBUG( "Current user %s is not limited", PostgresAccessor::getInstance().getBackend().userName().c_str() );
    return;
  }

  LOG_DEBUG( "Current user %s is limited", PostgresAccessor::getInstance().getBackend().userName().c_str() );
  using namespace  std::chrono_literals;
  PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TuplesQueryHandler>( 1000, 300ms );
}

void _PG_fini(void) {
  LOG_INFO( "Unloading query_supervisor.so from backend %d...", getpid() );
  BOOST_SCOPE_EXIT(void) {
      LOG_INFO( "query_supervisor.so unloaded from backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  if ( !isCurrentUserLimited() ) {
    return;
  }

  PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TuplesQueryHandler>();
}

} // extern "C"
