#include "query_handlers.hpp"

#include "configuration.hpp"
#include "postgres_accessor.hpp"


namespace PsqlTools::QuerySupervisor {
  using namespace  std::chrono_literals;

  bool TotalTuplesQueryHandler::breakQuery() const {
    if ( numberOfAllTuples() > PostgresAccessor::getInstance().getConfiguration().getTuplesLimit() ) {
      return true;
    }

    if ( getStatistics().at( SqlCommand::UPDATE ) > PostgresAccessor::getInstance().getConfiguration().getUpdatesLimit() ) {
      return true;
    }

    if ( getStatistics().at( SqlCommand::INSERT ) > PostgresAccessor::getInstance().getConfiguration().getInsertsLimit() ) {
      return true;
    }

    if ( getStatistics().at( SqlCommand::DELETE ) > PostgresAccessor::getInstance().getConfiguration().getDeleteLimit() ) {
      return true;
    }

    return false;
  }

  QueryHandlers::QueryHandlers()
  : m_timeoutQueryHandler( []{ return PostgresAccessor::getInstance().getConfiguration().getTimeoutLimit(); } )
  {
  }
} // namespace PsqlTools::QuerySupervisor
