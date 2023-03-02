#pragma once

#include "query_handler.h"

namespace PsqlTools::QuerySupervisor {
  class TimeoutQueryHandler
    : public QueryHandler
  {
    public:
    TimeoutQueryHandler();
    ~TimeoutQueryHandler() override = default;

    void onStartQuery( QueryDesc* _queryDesc, int _eflags ) override;
    void onEndQuery( QueryDesc* _queryDesc ) override;
    private:
  };
} // namespace PsqlTools::QuerySupervisor
