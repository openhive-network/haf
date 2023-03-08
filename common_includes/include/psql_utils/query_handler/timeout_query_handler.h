#pragma once

#include "query_handler.h"

#include <condition_variable>
#include <future>
#include <mutex>

#include "include/psql_utils/postgres_includes.hpp"

namespace PsqlTools::PsqlUtils {
  class TimeoutQueryHandler
    : public QueryHandler
  {
    public:
    TimeoutQueryHandler();
    ~TimeoutQueryHandler() override = default;

    void onStartQuery( QueryDesc* _queryDesc, int _eflags ) override;
    void onEndQuery( QueryDesc* _queryDesc ) override;
    void onRunQuery( QueryDesc* _queryDesc ) override;
    void onFinishQuery( QueryDesc* _queryDesc ) override;

    void onPeriodicCheck() override;

    private:
    void spawn();
    void addInstrumentation( QueryDesc* _queryDesc ) const;

    static void setPendingRootQuery( QueryDesc* _queryDesc );
    static bool isPendingRootQuery();
    static bool isEqualRootQuery( QueryDesc* _queryDesc );
    static bool isQueryCancelPending();

    private:
      TimeoutId m_pendingQueryTimeout{USER_TIMEOUT};
  };
} // namespace PsqlTools::PsqlUtils
