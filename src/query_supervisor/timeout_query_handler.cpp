#include "timeout_query_handler.h"

#include "include/psql_utils/logger.hpp"

#include <chrono>
#include <future>
#include <string>

bool allow_to_break = false;
std::future<void> timeout_future;
QueryDesc* root_queryDesc = nullptr;


namespace PsqlTools::QuerySupervisor {
  TimeoutQueryHandler::TimeoutQueryHandler() {

  }

  void TimeoutQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( isPendingRootQuery() ) {
      return;
    }

    setPendingRootQuery(_queryDesc);
    m_spawnedFuture = spawn();
  }

  void TimeoutQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( !isEqualRootQuery( _queryDesc ) ) {
      return;
    }

    LOG_DEBUG( "Root query end: %s", _queryDesc->sourceText );
    resetPendingRootQuery();
    m_conditionVariable.notify_one();
    if ( m_spawnedFuture.valid() ) {
      m_spawnedFuture.get();
      m_spawnedFuture = SpawnFuture{};
    }
  }

  void TimeoutQueryHandler::setPendingRootQuery( QueryDesc* _queryDesc ) {
    LOG_DEBUG( "Start pending root query end: %s", _queryDesc->sourceText );
    m_pendingRootQuery = _queryDesc;
  }
  bool TimeoutQueryHandler::isPendingRootQuery() const {
    return m_pendingRootQuery != nullptr;
  }

  void TimeoutQueryHandler::resetPendingRootQuery() {
    assert(m_pendingRootQuery!= nullptr);
    m_pendingRootQuery = nullptr;
  }

  bool TimeoutQueryHandler::isEqualRootQuery( QueryDesc* _queryDesc ) const {
    return m_pendingRootQuery == _queryDesc;
  }

  bool TimeoutQueryHandler::isQueryCancelPending() {
    return QueryCancelPending;
  }

  std::future<void> TimeoutQueryHandler::spawn() {
    auto thread_body = [this]{
      using namespace std::chrono_literals;
      std::unique_lock lock(m_mutex);
      bool isQueryStillPending = m_conditionVariable.wait_for(lock,1s,[this]{return !isPendingRootQuery();} );
      if ( !isQueryStillPending ) {
        LOG_DEBUG( "End of supervise thread because of root pending query ended" );
        return;
      }
      LOG_DEBUG( "Needs to break pending root query because of timeout" );
      StatementCancelHandler(0);
      resetPendingRootQuery();
    };

    return std::async( std::launch::async, thread_body );
  }
} // namespace PsqlTools::QuerySupervisor
