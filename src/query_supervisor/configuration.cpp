#include "configuration.hpp"

#include "psql_utils/logger.hpp"

#include <boost/algorithm/string.hpp>

#include <cassert>

namespace PsqlTools::QuerySupervisor {

  Configuration::Configuration()
    : m_wrappedCustomConfiguration( "query_supervisor" ) {
    LOG_DEBUG( "Initializing configuration..." );

    m_wrappedCustomConfiguration.addPositiveIntOption(
        LIMIT_TUPLES_OPTION
      , "Limited number of tuples"
      , "Limit of tuples which can be processed by the query"
      , DEFAULT_TUPLES_LIMIT
    );

    m_wrappedCustomConfiguration.addPositiveIntOption(
        LIMIT_TIMEOUT_OPTION
      , "Limited query time [ms]"
      , "Limit of time for a query execution [ms]"
      , DEFAULT_TIMEOUT_LIMIT_MS
    );

    m_wrappedCustomConfiguration.addBooleanOption(
         LIMITS_ENABLED
      , "Are limits enabled"
      , "If limits are enabled"
      , false
    );
    LOG_DEBUG( "Configuration initialized" );
  }

  uint32_t
  Configuration::getTuplesLimit() const {
    auto tuplesLimit  =
      m_wrappedCustomConfiguration.getOption( LIMIT_TUPLES_OPTION );

    assert( std::holds_alternative< uint32_t >( tuplesLimit ) );

    return std::get< uint32_t >( tuplesLimit );
  }

  std::chrono::milliseconds
  Configuration::getTimeoutLimit() const {
    auto timeoutLimit  =
      m_wrappedCustomConfiguration.getOption( LIMIT_TIMEOUT_OPTION );

    assert( std::holds_alternative< uint32_t >( timeoutLimit ) );

    return std::chrono::milliseconds( std::get< uint32_t >( timeoutLimit ) );
  }

  bool
  Configuration::areLimitsEnabled() const {
    auto option =
      m_wrappedCustomConfiguration.getOption( LIMITS_ENABLED );

    assert( std::holds_alternative< bool >( option ) );

    return std::get< bool >( option );
  }

}// PsqlTools::QuerySupervisor
