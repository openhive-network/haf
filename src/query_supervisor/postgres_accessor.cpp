#include "postgres_accessor.hpp"

#include "psql_utils/backend.h"
#include "psql_utils/custom_configuration.h"

#include <cassert>

namespace PsqlTools::QuerySupervisor {

  PostgresAccessor::PostgresAccessor() {
    m_customConfiguration = std::make_unique< PsqlUtils::CustomConfiguration >( "query_supervisor" );
    m_customConfiguration->addStringOption(
      "limited_users"
      , "Limited users names"
      , "List of users separated by commas whose queries are limited by the query_supervisor"
      , ""
    );

    m_backend = std::make_unique<PsqlUtils::Backend>();
  }

  PostgresAccessor& PostgresAccessor::getInstance() {
    // we can implement singleton in this way because
    // 1. postgres processes are always single threaded
    // 2. the object will live as long as postgres process - not needed to free it
    static PostgresAccessor instance;
    return instance;
  }

  const PsqlUtils::CustomConfiguration& PostgresAccessor::getCustomConfiguration() const {
    assert( m_customConfiguration );
    return *m_customConfiguration;
  }

  const PsqlUtils::Backend& PostgresAccessor::getBackend() const {
    assert( m_backend );
    return *m_backend;
  }

} // namespace PsqlTools::QuerySupervisor