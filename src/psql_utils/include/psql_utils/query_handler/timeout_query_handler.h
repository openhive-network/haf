#pragma once

#include "psql_utils/query_handler/root_query_handler.hpp"

#include <chrono>
#include <functional>

#include "psql_utils/postgres_includes.hpp"

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
    : public RootQueryHandler
  {
    public:
    using Limit = std::chrono::milliseconds;
    using TimeoutLimitGetter = std::function< Limit() >;

    TimeoutQueryHandler( TimeoutLimitGetter _limitGetter );
    ~TimeoutQueryHandler() override;

    void onRootQueryStart( QueryDesc* _queryDesc, int _eflags ) override;
    void onRootQueryEnd( QueryDesc* _queryDesc ) override;
    void onError(const QueryDesc& _queryDesc) override;

    private:
    void spawnTimer();

    private:
      const TimeoutLimitGetter m_timeoutLimitGetter;
      TimeoutId m_pendingQueryTimeout{USER_TIMEOUT};
  };
} // namespace PsqlTools::PsqlUtils
