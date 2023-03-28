#include "psql_utils/query_handler/timeout_query_handler.h"

#include "psql_utils/custom_configuration.h"
#include "psql_utils/logger.hpp"

#include <string>

namespace {
  void timeoutHandler() {
    StatementCancelHandler(0);
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
  }

  void TimeoutQueryHandler::onRootQueryStart( QueryDesc* _queryDesc, int _eflags ) {
    assert(_queryDesc);

    if ( isQueryCancelPending() ) {
      return;
    }

    spawnTimer();
  }

  void TimeoutQueryHandler::onRootQueryEnd( QueryDesc* _queryDesc ) {
    assert(_queryDesc);

    //Warning: onEndQuery won't be called when pending root query was broken;
    if ( isQueryCancelPending() ) {
      return;
    }

    disable_timeout( m_pendingQueryTimeout, false );
  }

  void TimeoutQueryHandler::spawnTimer() {
    enable_timeout_after( m_pendingQueryTimeout, m_queryTimeout.count() );
  }
} // namespace PsqlTools::PsqlUtils
