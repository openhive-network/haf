#include "include/psql_utils/query_handler/timeout_query_handler.h"

#include "include/psql_utils/custom_configuration.h"
#include "include/psql_utils/logger.hpp"

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
  TimeoutQueryHandler::TimeoutQueryHandler( std::chrono::milliseconds _queryTimeout )
    : m_queryTimeout( std::move(_queryTimeout) )
  {
    // no worries about fail of registration because pg will terminate backend
    m_pendingQueryTimeout = RegisterTimeout( USER_TIMEOUT, timeoutHandler );
  }

  TimeoutQueryHandler::~TimeoutQueryHandler() {
    disable_timeout( m_pendingQueryTimeout, true );
    if (TimeoutQueryHandler::isRootQueryPending()) {
      resetPendingRootQuery();
    }
  }

  void TimeoutQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    assert(_queryDesc);

    LOG_DEBUG( "Start query %s", _queryDesc->sourceText  );

    if ( isQueryCancelPending() ) {
      return;
    }

    if ( isRootQueryPending() ) {
      return;
    }

    setPendingRootQuery(_queryDesc);
    spawnTimer();
  }

  void TimeoutQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    assert(_queryDesc);

    LOG_DEBUG( "End query %s", _queryDesc->sourceText  );

    //Warning: onEndQuery won't be called when pending root query was broken;
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( !isPendingRootQuery(_queryDesc) ) {
      return;
    }

    disable_timeout( m_pendingQueryTimeout, false );
    resetPendingRootQuery();
  }

  void TimeoutQueryHandler::setPendingRootQuery( QueryDesc* _queryDesc ) {
    assert(_queryDesc);

    LOG_DEBUG( "Start root query: %s", _queryDesc->sourceText );
    m_pendingRootQuery = _queryDesc;
  }

  bool TimeoutQueryHandler::isRootQueryPending() {
    return m_pendingRootQuery != nullptr;
  }

  bool TimeoutQueryHandler::isPendingRootQuery(QueryDesc* _queryDesc ) {
    if ( _queryDesc == nullptr ) {
      return false;
    }
    return m_pendingRootQuery == _queryDesc;
  }

  bool TimeoutQueryHandler::isQueryCancelPending() {
    return QueryCancelPending;
  }

  void TimeoutQueryHandler::breakPendingRootQuery() {
    timeoutHandler();
  }

  QueryDesc* TimeoutQueryHandler::getPendingRootQuery() {
    return m_pendingRootQuery;
  }

  void TimeoutQueryHandler::spawnTimer() {
    enable_timeout_after( m_pendingQueryTimeout, m_queryTimeout.count() );
  }
} // namespace PsqlTools::PsqlUtils
