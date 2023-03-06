#include "include/psql_utils/backend.h"

namespace PsqlTools::PsqlUtils {

  Oid Backend::userid() const {
    return MyBEEntry->st_userid;
  }

} // namespace PsqlTools::PsqlUtils
