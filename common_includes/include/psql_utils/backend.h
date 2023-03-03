#pragma once

#include "include/psql_utils/postgres_includes.hpp"

namespace PsqlTools::PsqlUtils {

  class Backend {
  public:
    Backend();
    ~Backend() = default;

    Oid userid() const {return m_userId;}
  private:
    const Oid m_userId{};
  };

} // namespace PsqlTools::PsqlUtils

