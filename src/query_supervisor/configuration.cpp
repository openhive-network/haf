#include "configuration.hpp"

#include "psql_utils/logger.hpp"

#include <boost/algorithm/string.hpp>

#include <cassert>

namespace PsqlTools::QuerySupervisor {

  Configuration::Configuration()
    : m_wrappedCustomConfiguration( "query_supervisor" ) {
    m_wrappedCustomConfiguration.addStringOption(
        LIMITED_USERS_OPTION
      , "Limited users names"
      , "List of users separated by commas whose queries are limited by the query_supervisor"
      , ""
    );

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
  }

  std::vector<std::string>
  Configuration::getBlockedUsers() const {
    auto blockedUsersOptionValue  =
      m_wrappedCustomConfiguration.getOption( LIMITED_USERS_OPTION );

    assert( std::holds_alternative< std::string >( blockedUsersOptionValue ) );

    std::vector< std::string > result;
    return boost::split( result, std::get< std::string >( blockedUsersOptionValue ), boost::is_any_of(",") );
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

}// PsqlTools::QuerySupervisor
