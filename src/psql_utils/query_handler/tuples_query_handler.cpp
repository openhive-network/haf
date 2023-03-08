#include "include/psql_utils/query_handler/tuples_query_handler.h"

#include "include/psql_utils/logger.hpp"

#include <boost/scope_exit.hpp>

namespace PsqlTools::PsqlUtils {

  void TuplesQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    using namespace std::chrono_literals;

    BOOST_SCOPE_EXIT_ALL(_queryDesc, _eflags, this) {
      TimeoutQueryHandler::onStartQuery( _queryDesc, _eflags );
    };

    if ( isQueryCancelPending() ) {
      return;
    }

    if ( isPendingRootQuery() ) {
      return;
    }

    startPeriodicCheck( 1ms );
  }

  void TuplesQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    BOOST_SCOPE_EXIT_ALL(_queryDesc, this) {
        TimeoutQueryHandler::onEndQuery( _queryDesc );
    };
    if ( isQueryCancelPending() ) {
      stopPeriodicCheck();
      return;
    }

    if ( !isEqualRootQuery( _queryDesc ) ) {
      return;
    }

    stopPeriodicCheck();
  }

  void TuplesQueryHandler::onRunQuery( QueryDesc* _queryDesc ) {
    addInstrumentation( _queryDesc );
    TimeoutQueryHandler::onRunQuery(_queryDesc);
  }

  void TuplesQueryHandler::onFinishQuery( QueryDesc* _queryDesc ) {
    assert( _queryDesc );

    BOOST_SCOPE_EXIT_ALL(_queryDesc, this) {
      TimeoutQueryHandler::onFinishQuery( _queryDesc );
    };

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
    InstrAggNode(getPendingQuery()->totaltime, _queryDesc->totaltime );
  }

  void TuplesQueryHandler::onPeriodicCheck() {
    LOG_INFO( "Periodic check!" );

    if ( !isPendingRootQuery() ) {
      stopPeriodicCheck();
      return;
    }

    LOG_INFO( "Query ntuples %lf", getPendingQuery()->totaltime->tuplecount );

    if (  getPendingQuery()->totaltime->tuplecount > 1000 ) {
      LOG_INFO( "Break because more than 1000 touples were touched" );
      stopPeriodicCheck();
      breakPendingRootQuery();
    }
  }

  void TuplesQueryHandler::addInstrumentation( QueryDesc* _queryDesc ) const {
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

