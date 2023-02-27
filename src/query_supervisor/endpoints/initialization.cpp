#include "include/psql_utils/postgres_includes.hpp"

#include "initializer.hpp"



extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  PsqlTools::ForkExtension::Initializer initializer;
}

void _PG_fini(void) {

}

} // extern "C"
