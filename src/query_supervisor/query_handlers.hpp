#pragma once

#include "psql_utils/query_handler/timeout_query_handler.h"
#include "psql_utils/query_handler/tuples_statistics_query_handler.hpp"

namespace PsqlTools::QuerySupervisor {
  class TotalTuplesQueryHandler
    : public PsqlUtils::TuplesStatisticsQueryHandler
    {
      bool breakQuery() const override;
    };
  class QueryHandlers {
  public:
    QueryHandlers();
    ~QueryHandlers() = default;

  private:
    TotalTuplesQueryHandler m_tuplesHandler;
    PsqlUtils::TimeoutQueryHandler m_timeoutQueryHandler;
  };

} // namespace PsqlTools::QuerySupervisor
