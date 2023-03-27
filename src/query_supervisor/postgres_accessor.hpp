#pragma once

#include <memory>

namespace PsqlTools::PsqlUtils {
  class CustomConfiguration;
  class Backend;
} // namespace PsqlUtils

namespace PsqlTools::QuerySupervisor {

  class PostgresAccessor {
  public:
    ~PostgresAccessor() = default;

    static PostgresAccessor& getInstance();

    const PsqlUtils::CustomConfiguration& getCustomConfiguration() const;
    const PsqlUtils::Backend& getBackend() const;

  private:
    PostgresAccessor();

    std::unique_ptr< PsqlUtils::CustomConfiguration > m_customConfiguration;
    std::unique_ptr< PsqlUtils::Backend > m_backend;
  };

} // namespace PsqlTools::QuerySupervisor