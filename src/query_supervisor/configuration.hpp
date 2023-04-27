#pragma once

#include "psql_utils/custom_configuration.h"

#include <chrono>
#include <vector>

namespace PsqlTools::QuerySupervisor {

  class Configuration {
  public:
    static constexpr auto LIMIT_TUPLES_OPTION = "limit_tuples";
    static constexpr auto LIMIT_TIMEOUT_OPTION = "limit_timeout";
    static constexpr auto LIMITS_ENABLED = "limits_enabled";

    static constexpr auto DEFAULT_TUPLES_LIMIT = 1000;
    static constexpr auto DEFAULT_TIMEOUT_LIMIT_MS = 300;
    Configuration();
    ~Configuration() = default;

    uint32_t getTuplesLimit() const;
    std::chrono::milliseconds getTimeoutLimit() const;
    bool areLimitsEnabled() const;
  private:
    PsqlUtils::CustomConfiguration m_wrappedCustomConfiguration;
  };

} // namespace PsqlTools::QuerySupervisor
