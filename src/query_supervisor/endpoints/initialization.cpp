#include "include/psql_utils/postgres_includes.hpp"

#include "initializer.hpp"
#include "deinitializer.hpp"

extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  PsqlTools::QuerySupervisor::Initializer initializer;
}

void _PG_fini(void) {
  PsqlTools::QuerySupervisor::Deinitializer deinitializer;
}

} // extern "C"
