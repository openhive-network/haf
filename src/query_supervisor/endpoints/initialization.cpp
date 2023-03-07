#include "include/psql_utils/postgres_includes.hpp"

#include "include/psql_utils/query_handler/timeout_query_handler.h"

#include "include/psql_utils/custom_configuration.h"

PsqlTools::PsqlUtils::CustomConfiguration g_customConfiguration( "querysupervisor" );

extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>();
  g_customConfiguration.addStringOption( "hafadmin", "Name of haf admin role", "Name of haf admin role", "haf_admin" );
}

void _PG_fini(void) {
  PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>();
}

} // extern "C"
