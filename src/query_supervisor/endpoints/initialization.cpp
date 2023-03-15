#include "include/psql_utils/postgres_includes.hpp"

#include "include/psql_utils/query_handler/tuples_query_handler.h"

extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  LOG_INFO( "Loading query_supervisor.so into backend %d...", getpid() );
  using namespace  std::chrono_literals;
  PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TuplesQueryHandler>( 1000, 1s );
  LOG_INFO( "query_supervisor.so loaded into backend %d...", getpid() );
}

void _PG_fini(void) {
  LOG_INFO( "Unloading query_supervisor.so from backend %d...", getpid() );
  PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TuplesQueryHandler>();
  LOG_INFO( "query_supervisor.so unloaded from backend %d...", getpid() );
}

} // extern "C"
