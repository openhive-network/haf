#pragma once

#include <memory>

namespace PsqlTools::PsqlUtils {
  class Backend;
} // namespace PsqlUtils

namespace PsqlTools::QuerySupervisor {
  class Configuration;

  class PostgresAccessor {
  public:
    ~PostgresAccessor() = default;

    static PostgresAccessor& getInstance();

    const Configuration& getConfiguration() const;
    const PsqlUtils::Backend& getBackend() const;

  private:
    PostgresAccessor();

    std::unique_ptr< Configuration > m_configuration;
    std::unique_ptr< PsqlUtils::Backend > m_backend;
  };

} // namespace PsqlTools::QuerySupervisor