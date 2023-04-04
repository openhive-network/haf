#include "postgres_accessor.hpp"

#include "configuration.hpp"

#include "psql_utils/backend.h"

#include <cassert>

namespace PsqlTools::QuerySupervisor {

  PostgresAccessor::PostgresAccessor() {
    m_configuration = std::make_unique< Configuration >();
    m_backend = std::make_unique<PsqlUtils::Backend>();
  }

  PostgresAccessor& PostgresAccessor::getInstance() {
    // we can implement singleton in this way because
    // 1. postgres processes are always single threaded
    // 2. the object will live as long as postgres process - not needed to free it
    static PostgresAccessor instance;
    return instance;
  }

  const Configuration& PostgresAccessor::getConfiguration() const {
    assert( m_configuration );
    return *m_configuration;
  }

  const PsqlUtils::Backend& PostgresAccessor::getBackend() const {
    assert( m_backend );
    return *m_backend;
  }

} // namespace PsqlTools::QuerySupervisor