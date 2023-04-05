#include "postgres_accessor.hpp"

#include "configuration.hpp"

#include "psql_utils/backend.h"
#include "include/exceptions.hpp"

#include <cassert>

namespace PsqlTools::QuerySupervisor {

  PostgresAccessor::PostgresAccessor() {
    m_configuration = std::make_unique<Configuration>();

    try {
      m_backend = std::make_unique<PsqlUtils::Backend>();
    } catch ( ObjectInitializationException& _exception ){}
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

  std::optional< std::reference_wrapper< const PsqlUtils::Backend > > PostgresAccessor::getBackend() const {
    if ( m_backend == nullptr ) {
      return std::nullopt;
    }
    return *m_backend;
  }

} // namespace PsqlTools::QuerySupervisor