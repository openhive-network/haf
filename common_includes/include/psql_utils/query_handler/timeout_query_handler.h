#pragma once

#include "query_handler.h"

#include <condition_variable>
#include <future>
#include <mutex>
#include <optional>

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

    protected:
    static bool isPendingRootQuery();
    static bool isEqualRootQuery( QueryDesc* _queryDesc );
    static bool isQueryCancelPending();
    static void breakPendingRootQuery();

    // may return nullptr
    static QueryDesc* getPendingQuery();

    private:
    void spawn();

    static void setPendingRootQuery( QueryDesc* _queryDesc );

    private:
      TimeoutId m_pendingQueryTimeout{USER_TIMEOUT};
  };
} // namespace PsqlTools::PsqlUtils
