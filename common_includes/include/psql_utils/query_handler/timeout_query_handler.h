#pragma once

#include "query_handler.h"

#include <chrono>

#include "include/psql_utils/postgres_includes.hpp"

namespace PsqlTools::PsqlUtils {

  /**
   * The class is intended to check root query execution time
   * and break a query when given timeout is exceeded.
   * Because it inherits from QueryHandler, then no more than one of its object can exists
   * Implementation uses PSQL timeouts, based on SIG_ALARM, this allows the backend to remain a single-threaded process
   * The handler supervises a root of query statements and its children, i.e. function and its body statements.
   * The function call statement is named RootQuery to distinguish it from its sub statements.
   * Timeout value refers to the time of a root query execution ( which includes sub-statements times )
   */
  class TimeoutQueryHandler
    : public QueryHandler
  {
    public:
    TimeoutQueryHandler( std::chrono::milliseconds _queryTimeout );
    ~TimeoutQueryHandler() override = default;

    void onStartQuery( QueryDesc* _queryDesc, int _eflags ) override;
    void onEndQuery( QueryDesc* _queryDesc ) override;

    protected:
    static bool isRootQueryPending();
    static bool isPendingRootQuery(QueryDesc* _queryDesc );
    static bool isQueryCancelPending();
    static void breakPendingRootQuery();

    // may return nullptr
    static QueryDesc* getPendingRootQuery();

    private:
    void spawnTimer();

    static void setPendingRootQuery( QueryDesc* _queryDesc );

    private:
      const std::chrono::milliseconds m_queryTimeout;
      TimeoutId m_pendingQueryTimeout{USER_TIMEOUT};
  };
} // namespace PsqlTools::PsqlUtils
