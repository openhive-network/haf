#include "include/psql_utils/query_handler/tuples_query_handler.h"

namespace PsqlTools::PsqlUtils {

  void TuplesQueryHandler::onRunQuery( QueryDesc* _queryDesc ) {
    addInstrumentation( _queryDesc );
  }

  void TuplesQueryHandler::onFinishQuery( QueryDesc* _queryDesc ) {
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

  void TuplesQueryHandler::onPeriodicCheck() {
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

  void TuplesQueryHandler::addInstrumentation( QueryDesc* _queryDesc ) {
    // Add instrumentation to track query resources
    if ( _queryDesc->totaltime != nullptr ) {
      return;
    }

    MemoryContext oldCxt;
    oldCxt = MemoryContextSwitchTo(_queryDesc->estate->es_query_cxt);
    _queryDesc->totaltime = InstrAlloc(1, INSTRUMENT_ALL, true);
    MemoryContextSwitchTo(oldCxt);
  }

} // namespace PsqlTools::PsqlUtils

