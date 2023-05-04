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

  assert( PostgresAccessor::getInstance().getBackend() );

  if ( PostgresAccessor::getInstance().getConfiguration().areLimitsEnabled() ) {
    return true;
  }

  bool a = is_member_of_role( GetUserId(), 397087 );

  /*if ( is_member_of_role( GetUserId(), 397087 ) ) {
    LOG_INFO( "Jest memberem grupy limitowanej" );
    return true;
  }*/
  LOG_INFO( "NIE Jest memberem grupy limitowanej" );

  /*for ( auto const& groupName : PostgresAccessor::getInstance().getConfiguration().getLimitedGroups() ) {

    auto role_tuple = SearchSysCache1(AUTHNAME, PointerGetDatum(groupName.c_str()));
    if (HeapTupleIsValid(role_tuple)) {
      auto role = (Form_pg_authid) GETSTRUCT(role_tuple);

      if ( is_member_of_role( GetUserId(), role->oid ) ) {
        ReleaseSysCache(role_tuple);
        return true;
      }

      ReleaseSysCache(role_tuple);
    }
  }*/

  return false;
}

std::unique_ptr< PsqlTools::QuerySupervisor::QueryHandlers > g_queryHandlers;

void _PG_init(void) {
  using PsqlTools::QuerySupervisor::PostgresAccessor;

  LOG_INFO( "Loading query_supervisor.so into backend %d...", getpid() );

  BOOST_SCOPE_EXIT(void) {
    LOG_INFO( "query_supervisor.so loaded into backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  if ( PostgresAccessor::getInstance().getBackend() == std::nullopt ) {
    LOG_DEBUG( "Process %d is not a backend, limitations are not checked", getpid() );
    return;
  }

  if ( !isCurrentUserLimited() ) {
    LOG_DEBUG( "Current user %s is not limited", PostgresAccessor::getInstance().getBackend()->get().userName().c_str() );
    return;
  }

  LOG_DEBUG( "Current user %s is limited", PostgresAccessor::getInstance().getBackend()->get().userName().c_str() );

  g_queryHandlers = std::make_unique< PsqlTools::QuerySupervisor::QueryHandlers >();
}

void _PG_fini(void) {
  LOG_INFO( "Unloading query_supervisor.so from backend %d...", getpid() );
  BOOST_SCOPE_EXIT(void) {
      LOG_INFO( "query_supervisor.so unloaded from backend %d...", getpid() );
  } BOOST_SCOPE_EXIT_END

  g_queryHandlers.reset();
}

} // extern "C"
