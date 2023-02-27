#include "include/psql_utils/backend.h"

namespace PsqlTools::PsqlUtils {

  Oid Backend::userOid() const {
    return MyBEEntry->st_userid;
  }

  std::string Backend::userName() const {
    auto user = userOid();
    return MappingUserName(user);
  }

} // namespace PsqlTools::PsqlUtils
