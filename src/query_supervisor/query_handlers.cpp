#include "query_handlers.hpp"

#include "configuration.hpp"
#include "postgres_accessor.hpp"


namespace PsqlTools::QuerySupervisor {
  using namespace  std::chrono_literals;

  QueryHandlers::QueryHandlers()
  : m_tuplesQueryHandler( []{ return PostgresAccessor::getInstance().getConfiguration().getTuplesLimit(); } )
  , m_timeoutQueryHandler( []{ return PostgresAccessor::getInstance().getConfiguration().getTimeoutLimit(); } )
  {
  }
} // namespace PsqlTools::QuerySupervisor
