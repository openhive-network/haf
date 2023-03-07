#include "include/psql_utils/query_handler/timeout_query_handler.h"

#include "include/psql_utils/custom_configuration.h"
#include "include/psql_utils/logger.hpp"

#include <chrono>
#include <string>

namespace {
  QueryDesc* m_pendingRootQuery{nullptr};

  void resetPendingRootQuery() {
    assert(m_pendingRootQuery!= nullptr);
    m_pendingRootQuery = nullptr;
  }

  void timeoutHandler() {
    StatementCancelHandler(0);
    resetPendingRootQuery();
  }

} // namespace



namespace PsqlTools::PsqlUtils {
  TimeoutQueryHandler::TimeoutQueryHandler() {
    m_pendingQueryTimeout = RegisterTimeout( USER_TIMEOUT, timeoutHandler );
  }

  void TimeoutQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    LOG_DEBUG( "start query %s", _queryDesc->sourceText  );
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( isPendingRootQuery() ) {
      return;
    }

    TimeoutQueryHandler::setPendingRootQuery(_queryDesc);
    spawn();
  }

  void TimeoutQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    LOG_DEBUG( "end query %s", _queryDesc->sourceText  );
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( !isEqualRootQuery( _queryDesc ) ) {
      return;
    }

    LOG_DEBUG( "Root query end: %s", _queryDesc->sourceText );
    disable_timeout( m_pendingQueryTimeout, false );
    resetPendingRootQuery();
  }

  void TimeoutQueryHandler::setPendingRootQuery( QueryDesc* _queryDesc ) {
    LOG_DEBUG( "Start pending root query end: %s", _queryDesc->sourceText );
    m_pendingRootQuery = _queryDesc;
  }
  bool TimeoutQueryHandler::isPendingRootQuery() {
    return m_pendingRootQuery != nullptr;
  }



  bool TimeoutQueryHandler::isEqualRootQuery( QueryDesc* _queryDesc ) {
    return m_pendingRootQuery == _queryDesc;
  }

  bool TimeoutQueryHandler::isQueryCancelPending() {
    return QueryCancelPending;
  }

  void TimeoutQueryHandler::spawn() {
    using namespace std::chrono_literals;
    auto delay = 1s;
    enable_timeout_after( m_pendingQueryTimeout, std::chrono::duration_cast< std::chrono::milliseconds >(delay).count() );
  }
} // namespace PsqlTools::PsqlUtils
