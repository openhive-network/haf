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
    // no worries about fail of registration because pg will terminate backend
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
    //Warning: onEndQuery won't be called when pending root query was broken
    LOG_DEBUG( "end query %s", _queryDesc->sourceText  );
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( !isEqualRootQuery( _queryDesc ) ) {
      return;
    }

    LOG_INFO( "Query ntuples %lf", m_pendingRootQuery->totaltime->tuplecount );

    stopPeriodicCheck();
    LOG_DEBUG( "Root query end: %s", _queryDesc->sourceText );
    disable_timeout( m_pendingQueryTimeout, false );
    resetPendingRootQuery();
  }

  void TimeoutQueryHandler::onRunQuery( QueryDesc* _queryDesc ) {
    addInstrumentation( _queryDesc );
  }

  void TimeoutQueryHandler::onFinishQuery( QueryDesc* _queryDesc ) {
    assert( _queryDesc );
    LOG_INFO( "Finish query: %s, %lf", _queryDesc->sourceText, _queryDesc->totaltime->tuplecount );
    if ( isQueryCancelPending() ) {
      return;
    }

    if ( isEqualRootQuery( _queryDesc ) ) {
      return;
    }

    assert( m_pendingRootQuery );
    assert( m_pendingRootQuery->totaltime );
    assert( _queryDesc->totaltime );
    InstrAggNode(m_pendingRootQuery->totaltime, _queryDesc->totaltime );
  }

  void TimeoutQueryHandler::onPeriodicCheck() {
    LOG_INFO( "Periodic check!" );
    if ( !isPendingRootQuery() ) {
      stopPeriodicCheck();
      return;
    }

    if (m_pendingRootQuery) {
      LOG_INFO( "Query ntuples %lf", m_pendingRootQuery->totaltime->tuplecount );
      if (  m_pendingRootQuery->totaltime->tuplecount > 1000 ) {
        LOG_INFO( "Break because more than 1000 touples were touched" );
        timeoutHandler();
      }
    }
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
    auto delay = 5s;
    enable_timeout_after( m_pendingQueryTimeout, std::chrono::duration_cast< std::chrono::milliseconds >(delay).count() );
    startPeriodicCheck( 1ms );
  }

  void TimeoutQueryHandler::addInstrumentation( QueryDesc* _queryDesc ) const {
    LOG_INFO( "Set instrumentation" );
    // Add instrumentation to track query resources
    if ( _queryDesc->totaltime != nullptr ) {
      return;
    }
    MemoryContext oldcxt;
    oldcxt = MemoryContextSwitchTo(_queryDesc->estate->es_query_cxt);
    _queryDesc->totaltime = InstrAlloc(1, INSTRUMENT_ALL, true);
    MemoryContextSwitchTo(oldcxt);
  }
} // namespace PsqlTools::PsqlUtils
