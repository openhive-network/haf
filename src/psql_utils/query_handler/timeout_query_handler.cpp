#include "include/psql_utils/query_handler/timeout_query_handler.h"

#include "include/psql_utils/custom_configuration.h"
#include "include/psql_utils/logger.hpp"

#include <chrono>
#include <string>

namespace {
  QueryDesc* m_pendingRootQuery{nullptr};

  void resetPendingRootQuery() {
    assert(m_pendingRootQuery!= nullptr);

    LOG_DEBUG( "Root query end: %s", m_pendingRootQuery->sourceText );
    m_pendingRootQuery = nullptr;
  }

  void timeoutHandler() {
    StatementCancelHandler(0);
    resetPendingRootQuery();
  }

} // namespace



namespace PsqlTools::PsqlUtils {
  TimeoutQueryHandler::TimeoutQueryHandler() {
    // no worries about fail of registration because pg will terminate backend
    m_pendingQueryTimeout = RegisterTimeout( USER_TIMEOUT, timeoutHandler );
  }

  void TimeoutQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    LOG_DEBUG( "Start query %s", _queryDesc->sourceText  );

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
    //Warning: onEndQuery won't be called when pending root query was broken
    LOG_DEBUG( "End query %s", _queryDesc->sourceText  );
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( !isEqualRootQuery( _queryDesc ) ) {
      return;
    }

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

  void TimeoutQueryHandler::breakPendingRootQuery() {
    timeoutHandler();
  }

  QueryDesc* TimeoutQueryHandler::getPendingQuery() {
    return m_pendingRootQuery;
  }

  void TimeoutQueryHandler::spawn() {
    using namespace std::chrono_literals;
    auto delay = 5s;
    enable_timeout_after( m_pendingQueryTimeout, std::chrono::duration_cast< std::chrono::milliseconds >(delay).count() );
  }
} // namespace PsqlTools::PsqlUtils
