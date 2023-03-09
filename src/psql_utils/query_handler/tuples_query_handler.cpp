#include "include/psql_utils/query_handler/tuples_query_handler.h"

#include "include/psql_utils/logger.hpp"

#include <boost/scope_exit.hpp>

namespace PsqlTools::PsqlUtils {

  TuplesQueryHandler::TuplesQueryHandler(
      uint32_t _limitOfTuplesPerRootQuery
    , std::chrono::milliseconds _periodicCheckPeriod
    , std::chrono::milliseconds _queryTimeout
  )
    : TimeoutQueryHandler( _queryTimeout )
    , m_limitOfTuplesPerRootQuery(_limitOfTuplesPerRootQuery)
    , m_period( _periodicCheckPeriod )
  {}

  void TuplesQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    using namespace std::chrono_literals;

    BOOST_SCOPE_EXIT_ALL(_queryDesc, _eflags, this) {
      TimeoutQueryHandler::onStartQuery( _queryDesc, _eflags );
    };

    if ( isQueryCancelPending() ) {
      return;
    }

    if (isRootQueryPending() ) {
      return;
    }

    startPeriodicCheck( m_period );
  }

  void TuplesQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    BOOST_SCOPE_EXIT_ALL(_queryDesc, this) {
        TimeoutQueryHandler::onEndQuery( _queryDesc );
    };
    if ( isQueryCancelPending() ) {
      stopPeriodicCheck();
      return;
    }

    if ( !isPendingRootQuery(_queryDesc) ) {
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

    if (isPendingRootQuery(_queryDesc) ) {
      return;
    }

    assert( isRootQueryPending() );
    assert( getPendingRootQuery()->totaltime );
    assert( _queryDesc->totaltime );
    InstrAggNode(getPendingRootQuery()->totaltime, _queryDesc->totaltime );
  }

  void TuplesQueryHandler::onPeriodicCheck() {
    if ( !isRootQueryPending() ) {
      stopPeriodicCheck();
      return;
    }

    if (getPendingRootQuery()->totaltime->tuplecount > m_limitOfTuplesPerRootQuery ) {
      LOG_WARNING("Query was broken because of tuples limit reached %lf > %d"
                   , getPendingRootQuery()->totaltime->tuplecount
                   , m_limitOfTuplesPerRootQuery
      );
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

