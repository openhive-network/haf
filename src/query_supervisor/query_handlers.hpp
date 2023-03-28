#pragma once

#include "psql_utils/query_handler/timeout_query_handler.h"
#include "psql_utils/query_handler/tuples_query_handler.h"

namespace PsqlTools::QuerySupervisor {

  class QueryHandlers {
  public:
    QueryHandlers();
    ~QueryHandlers() = default;

  private:
    PsqlUtils::TuplesQueryHandler m_tuplesQueryHandler;
    PsqlUtils::TimeoutQueryHandler m_timeoutQueryHandler;
  };

} // namespace PsqlTools::QuerySupervisor
