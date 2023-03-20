#pragma once

#include "include/psql_utils/postgres_includes.hpp"

#include <string>

namespace PsqlTools::PsqlUtils {

  class Backend {
  public:
    Backend() = default;
    ~Backend() = default;

    Oid userOid() const;
    std::string userName() const;
  };

} // namespace PsqlTools::PsqlUtils

