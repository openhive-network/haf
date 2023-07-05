#include "psql_utils/query_handler/timeout_query_handler.h"

#include "psql_utils/custom_configuration.h"
#include "psql_utils/logger.hpp"

#include <string>

namespace {
  void timeoutHandler() {
    LOG_WARNING( "The query was terminated due to a timeout being reached." );
    StatementCancelHandler(0);
  }
} // namespace

namespace PsqlTools::PsqlUtils {
  TimeoutQueryHandler::TimeoutQueryHandler( TimeoutLimitGetter _limitGetter  )
    : m_timeoutLimitGetter( _limitGetter )
  {
    // no worries about fail of registration because pg will terminate backend
    m_pendingQueryTimeout = RegisterTimeout( USER_TIMEOUT, timeoutHandler );
  }

  TimeoutQueryHandler::~TimeoutQueryHandler() {
    disable_timeout( m_pendingQueryTimeout, true );
  }

  void TimeoutQueryHandler::onRootQueryStart( QueryDesc* _queryDesc, int _eflags ) {
    assert(_queryDesc);
    spawnTimer();
  }

  void TimeoutQueryHandler::onRootQueryEnd( QueryDesc* _queryDesc ) {
    assert(_queryDesc);
    disable_timeout( m_pendingQueryTimeout, false );
  }

  void TimeoutQueryHandler::onError(const QueryDesc& _queryDesc) {
    disable_timeout( m_pendingQueryTimeout, false );
    RootQueryHandler::onError(_queryDesc);
  }

  void TimeoutQueryHandler::spawnTimer() {
    assert( m_timeoutLimitGetter );
    enable_timeout_after( m_pendingQueryTimeout, m_timeoutLimitGetter().count() );
  }
} // namespace PsqlTools::PsqlUtils
