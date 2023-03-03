#include <include/psql_utils/backend.h>

#include <include/exceptions.hpp>


namespace {
  PgBackendStatus& getBackendStatus() {
    using namespace PsqlTools;
    auto beid = 0;//PG_GETARG_INT32(0);
    PgBackendStatus *beentry;

    if ((beentry = pgstat_fetch_stat_beentry(beid)) == NULL) {
      THROW_INITIALIZATION_ERROR( "Cannot get backed stat entry" );
    }

    return *beentry;
  }
}


namespace PsqlTools::PsqlUtils {

  Backend::Backend()
    : m_userId{ PgBackendStatus().st_userid }
  {

  }

} // namespace PsqlTools::PsqlUtils
