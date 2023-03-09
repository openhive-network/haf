#include "include/psql_utils/postgres_includes.hpp"

#include "include/psql_utils/query_handler/tuples_query_handler.h"

extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  using namespace  std::chrono_literals;
  PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TuplesQueryHandler>( 1000, 10ms, 1s );
}

void _PG_fini(void) {
  PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TuplesQueryHandler>();
}

} // extern "C"
