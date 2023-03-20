#include "include/psql_utils/postgres_includes.hpp"

#include "include/psql_utils/query_handler/tuples_query_handler.h"
#include "include/psql_utils/custom_configuration.h"

#include <boost/scope_exit.hpp>

#include <chrono>
#include <memory>

extern "C" {
  PG_MODULE_MAGIC;

  std::unique_ptr< PsqlTools::PsqlUtils::CustomConfiguration > g_customConfiguration;

void _PG_init(void) {
  LOG_INFO( "Loading query_supervisor.so into backend %d...", getpid() );

  BOOST_SCOPE_EXIT(void) {
    LOG_INFO( "query_supervisor.so loaded into backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  using namespace  std::chrono_literals;

  g_customConfiguration = std::make_unique< PsqlTools::PsqlUtils::CustomConfiguration >( "query_supervisor" );
  g_customConfiguration->addStringOption(
      "limited_users"
    , "Limited users names"
    , "List of users separated by commas whose queries are limited by the query_supervisor"
    , ""
    );

  const auto limitedUsers = g_customConfiguration->getOptionAsString( "limited_users" );

  LOG_INFO( "Limited users: {%s}", limitedUsers.c_str() );

  if ( limitedUsers.empty() ) {
    return;
  }

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
