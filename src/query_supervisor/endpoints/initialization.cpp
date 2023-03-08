#include "include/psql_utils/postgres_includes.hpp"

#include "include/psql_utils/query_handler/tuples_query_handler.h"

extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TuplesQueryHandler>();
}

void _PG_fini(void) {
  PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TuplesQueryHandler>();
}

} // extern "C"
