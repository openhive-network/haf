#include "psql_utils/postgres_includes.hpp"

#include "postgres_mock.hpp"

sigjmp_buf* PG_exception_stack = nullptr;
ErrorContextCallback *error_context_stack = nullptr;

extern "C" {

static int last_elevel = 0;
static int last_errcode = 0;

// at the moment not used for test
void elog_start([[maybe_unused]] const char *filename, [[maybe_unused]]  int lineno, [[maybe_unused]] const char *funcname)
{
}

void elog_finish([[maybe_unused]] int elevel, [[maybe_unused]] const char *fmt,...)
{
}

int errcode(int sqlerrcode)
{
  last_errcode = sqlerrcode;
  return 0;
}

int errmsg(const char* [[maybe_unused]] fmt,...)
{
  return 0;
}

bool errstart(int elevel, [[maybe_unused]] const char *domain) {
  last_elevel = elevel;
  return true;
}

void errfinish([[maybe_unused]] const char *filename, [[maybe_unused]] int lineno, [[maybe_unused]] const char *funcname) {
  if (last_elevel >= ERROR)
  {
    siglongjmp( *PG_exception_stack, 1 );
  }
}

int	errmsg_internal([[maybe_unused]] const char *fmt,...) {
  return 0;
}

bool errstart_cold(int elevel, [[maybe_unused]] const char *domain){
  last_elevel = elevel;
  return true;
}

ErrorData* CopyErrorData(void)
{
  // TODO: check that this function is called with MemoryContext different than ErrorContext.
  // This is required by Postgres implementation of CopyErrorData.
  static ErrorData e{};
  return &e;
}

int geterrcode(void)
{
  return last_errcode;
}

} // extern "C"
