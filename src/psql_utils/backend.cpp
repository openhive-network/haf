#include "psql_utils/postgres_backend_includes.hpp"
#include "psql_utils/backend.h"

namespace PsqlTools::PsqlUtils {

  Oid Backend::userOid() const {
    return GetSessionUserId();
  }

  std::string Backend::userName() const {
    if ( !MyProcPort->user_name ) {
      return "";
    }
    return MyProcPort->user_name;
  }

} // namespace PsqlTools::PsqlUtils
