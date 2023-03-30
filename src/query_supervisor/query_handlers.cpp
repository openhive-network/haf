#include "query_handlers.hpp"

#include "postgres_accessor.hpp"

namespace PsqlTools::QuerySupervisor {
  using namespace  std::chrono_literals;

  QueryHandlers::QueryHandlers()
  : m_tuplesQueryHandler( []{ return 1000; } )
  , m_timeoutQueryHandler( 300ms )
  {
  }
} // namespace PsqlTools::QuerySupervisor
