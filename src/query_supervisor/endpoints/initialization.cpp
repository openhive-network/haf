#include "include/psql_utils/postgres_includes.hpp"

#include "include/psql_utils/backend.h"
#include "include/psql_utils/custom_configuration.h"
#include "include/psql_utils/query_handler/tuples_query_handler.h"

#include <boost/algorithm/string.hpp>
#include <boost/scope_exit.hpp>

#include <chrono>
#include <memory>
#include <vector>

extern "C" {
  PG_MODULE_MAGIC;

  std::unique_ptr< PsqlTools::PsqlUtils::CustomConfiguration > g_customConfiguration;
  std::unique_ptr< PsqlTools::PsqlUtils::Backend > g_backend;

void initializeGlobals() {
  g_customConfiguration = std::make_unique< PsqlTools::PsqlUtils::CustomConfiguration >( "query_supervisor" );
  g_customConfiguration->addStringOption(
      "limited_users"
    , "Limited users names"
    , "List of users separated by commas whose queries are limited by the query_supervisor"
    , ""
  );

  g_backend = std::make_unique<PsqlTools::PsqlUtils::Backend>();
}

bool isCurrentUserLimited() {
  const auto limitedUsersString = g_customConfiguration->getOptionAsString( "limited_users" );

  LOG_DEBUG( "Limited users: {%s}", limitedUsersString.c_str() );

  if ( limitedUsersString.empty() ) {
    return false;
  }

  initializeGlobals();

  std::vector< std::string > users;
  boost::split( users, limitedUsersString, boost::is_any_of(",") );

  auto userIt = std::find( users.begin(), users.end(), g_backend->userName() );
  return userIt != users.end();
}

void _PG_init(void) {
  LOG_INFO( "Loading query_supervisor.so into backend %d...", getpid() );

  BOOST_SCOPE_EXIT(void) {
    LOG_INFO( "query_supervisor.so loaded into backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  using namespace  std::chrono_literals;




  PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TuplesQueryHandler>( 1000, 1s );
}

void _PG_fini(void) {
  LOG_INFO( "Unloading query_supervisor.so from backend %d...", getpid() );
  BOOST_SCOPE_EXIT(void) {
      LOG_INFO( "query_supervisor.so unloaded from backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  const auto limitedUsers = g_customConfiguration->getOptionAsString( "limited_users" );

  if ( limitedUsers.empty() ) {
    return;
  }

  PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TuplesQueryHandler>();
}

} // extern "C"
