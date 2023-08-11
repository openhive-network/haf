#include "psql_utils/postgres_includes.hpp"

#include <string.h>

char* pstrdup(const char *in)
{
  return strdup(in);
}
char* pnstrdup(const char *in, Size len)
{
  return strndup(in, len);
}

