#include "include/psql_utils/backend.h"

#include "include/psql_utils/logger.hpp"


namespace PsqlTools::PsqlUtils {

  Oid Backend::userOid() const {
    return GetSessionUserId();
  }

  std::string Backend::userName() const {
    const auto user = userOid();

    return GetUserNameFromId(user, false);
  }

} // namespace PsqlTools::PsqlUtils
