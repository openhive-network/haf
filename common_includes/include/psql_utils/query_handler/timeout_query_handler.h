#pragma once

#include "query_handler.h"

#include <condition_variable>
#include <future>
#include <mutex>

namespace PsqlTools::PsqlUtils {
  class TimeoutQueryHandler
    : public QueryHandler
  {
    public:
    TimeoutQueryHandler();
    ~TimeoutQueryHandler() override = default;

    void onStartQuery( QueryDesc* _queryDesc, int _eflags ) override;
    void onEndQuery( QueryDesc* _queryDesc ) override;

    private:
    using SpawnFuture = std::future<void>;
    SpawnFuture spawn();

    void setPendingRootQuery( QueryDesc* _queryDesc );
    bool isPendingRootQuery() const;
    void resetPendingRootQuery();
    bool isEqualRootQuery( QueryDesc* _queryDesc ) const;
    static bool isQueryCancelPending();

    private:
    std::mutex m_mutex;
    SpawnFuture m_spawnedFuture;
    std::condition_variable m_conditionVariable;
    QueryDesc* m_pendingRootQuery{nullptr };
  };
} // namespace PsqlTools::PsqlUtils
