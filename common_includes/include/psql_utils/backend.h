#pragma once

#include "include/psql_utils/postgres_includes.hpp"

namespace PsqlTools::PsqlUtils {

  class Backend {
  public:
    Backend();
    ~Backend() = default;

    Oid userid() const;
  };

} // namespace PsqlTools::PsqlUtils

