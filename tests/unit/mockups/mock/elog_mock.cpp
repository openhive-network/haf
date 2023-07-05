#include "psql_utils/postgres_includes.hpp"

sigjmp_buf* PG_exception_stack = nullptr;
ErrorContextCallback *error_context_stack = nullptr;

extern "C" {

// at the moment not used for test
void elog_start([[maybe_unused]] const char *filename, [[maybe_unused]]  int lineno, [[maybe_unused]] const char *funcname)
{
}

void elog_finish([[maybe_unused]] int elevel, [[maybe_unused]] const char *fmt,...)
{
}

bool errstart([[maybe_unused]] int elevel, [[maybe_unused]] const char *domain) {
  return true;
}

void errfinish([[maybe_unused]] const char *filename, [[maybe_unused]] int lineno, [[maybe_unused]] const char *funcname) {
}

int	errmsg_internal([[maybe_unused]] const char *fmt,...) {
  return 0;
}

bool errstart_cold([[maybe_unused]] int elevel, [[maybe_unused]] const char *domain){
  return true;
}

void pg_re_throw(void) { abort(); }

} // extern "C"
