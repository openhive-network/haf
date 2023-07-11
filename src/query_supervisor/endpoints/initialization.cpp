#include "psql_utils/postgres_includes.hpp"

#include "configuration.hpp"
#include "postgres_accessor.hpp"
#include "query_handlers.hpp"

#include "psql_utils/backend.h"

#include <boost/scope_exit.hpp>

#include <chrono>
#include <memory>
#include <vector>

extern "C" {
  PG_MODULE_MAGIC;

bool isCurrentUserLimited() {
  using PsqlTools::QuerySupervisor::PostgresAccessor;
  return PostgresAccessor::getInstance().getConfiguration().areLimitsEnabled();
}

std::unique_ptr< PsqlTools::QuerySupervisor::QueryHandlers > g_queryHandlers;

void _PG_init(void) {
  using PsqlTools::QuerySupervisor::PostgresAccessor;

  LOG_DEBUG( "Loading query_supervisor.so into backend %d...", getpid() );

  BOOST_SCOPE_EXIT(void) {
    LOG_DEBUG( "query_supervisor.so loaded into backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  if ( !isCurrentUserLimited() ) {
    if ( PostgresAccessor::getInstance().getBackend() ) {
      LOG_DEBUG( "Current user %s is not limited",
                 PostgresAccessor::getInstance().getBackend()->get().userName().c_str());
      return;
    }
    LOG_DEBUG( "The current user of no regular backed process is not limited" );
    return;
  }

  if ( PostgresAccessor::getInstance().getBackend() ) {
    LOG_DEBUG( "Current user %s is limited", PostgresAccessor::getInstance().getBackend()->get().userName().c_str());
  }
  else {
    LOG_DEBUG( "The current user of no regular backed process is limited" );
  };

  g_queryHandlers = std::make_unique< PsqlTools::QuerySupervisor::QueryHandlers >();
}

void _PG_fini(void) {
  LOG_DEBUG( "Unloading query_supervisor.so from backend %d...", getpid() );
  BOOST_SCOPE_EXIT(void) {
    LOG_DEBUG( "query_supervisor.so unloaded from backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  g_queryHandlers.reset();
}

} // extern "C"
