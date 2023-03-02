#include "include/psql_utils/postgres_includes.hpp"

#include "timeout_query_handler.h"


extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  PsqlTools::QuerySupervisor::QueryHandler::initialize<PsqlTools::QuerySupervisor::TimeoutQueryHandler>();
}

void _PG_fini(void) {
  PsqlTools::QuerySupervisor::QueryHandler::deinitialize<PsqlTools::QuerySupervisor::TimeoutQueryHandler>();
}

} // extern "C"
