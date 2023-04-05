#include "psql_utils/postgres_backend_includes.hpp"
#include "psql_utils/backend.h"

#include "psql_utils/logger.hpp"

#include "include/exceptions.hpp"

namespace PsqlTools::PsqlUtils {

  Backend::Backend() {
    if ( MyProcPort == nullptr ) {
      THROW_INITIALIZATION_ERROR( "Worker is not a regular backend process" );
    }
  }

  Oid Backend::userOid() const {
    return GetSessionUserId();
  }

  std::string Backend::userName() const {
    LOG_DEBUG( "Backend::userName MyProcPort=%p BackgroundWorker=%p", MyProcPort, MyBgworkerEntry );
    if ( !MyProcPort->user_name ) {
      return "";
    }
    return MyProcPort->user_name;
  }

} // namespace PsqlTools::PsqlUtils
