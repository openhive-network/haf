#include "psql_utils/query_handler/tuples_query_handler.h"

#include "psql_utils/logger.hpp"

#include <boost/scope_exit.hpp>


namespace PsqlTools::PsqlUtils {

  TuplesQueryHandler::TuplesQueryHandler( TuplesLimitGetter _tuplesLimitGetter )
    : m_tuplesLimitGetter( _tuplesLimitGetter )
  {
    assert( m_tuplesLimitGetter );
  }

  void TuplesQueryHandler::onRootQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {
    m_limitOfTuplesPerRootQuery = m_tuplesLimitGetter();
    addInstrumentation( _queryDesc );
  }

  void TuplesQueryHandler::onSubQueryRun( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {
    assert( m_limitOfTuplesPerRootQuery );

    addInstrumentation( _queryDesc );
  }

  void TuplesQueryHandler::onRootQueryFinish( QueryDesc* _queryDesc ) {
    assert( _queryDesc );
    assert( m_limitOfTuplesPerRootQuery );

    LOG_DEBUG( "Finish root query: %s with tuples:  %lf", _queryDesc->sourceText, _queryDesc->totaltime->tuplecount );
    if ( isQueryCancelPending() ) {
      return;
    }

    checkTuplesLimit();
    m_limitOfTuplesPerRootQuery.reset();
  }

  void TuplesQueryHandler::onSubQueryFinish( QueryDesc* _queryDesc ) {
    assert( _queryDesc );
    assert( m_limitOfTuplesPerRootQuery );

    LOG_DEBUG( "Finish sub query: %s with tuples:  %lf", _queryDesc->sourceText, _queryDesc->totaltime->tuplecount );
    if ( isQueryCancelPending() ) {
      return;
    }

    assert( getRootQuery()->totaltime );
    assert( _queryDesc->totaltime );

    InstrAggNode( getRootQuery()->totaltime, _queryDesc->totaltime );

    checkTuplesLimit();
  }

  void TuplesQueryHandler::checkTuplesLimit() {
    assert( m_limitOfTuplesPerRootQuery );

    if (getRootQuery()->totaltime->tuplecount > m_limitOfTuplesPerRootQuery.value() ) {
      LOG_WARNING("Query was broken because of tuples limit reached %lf > %d"
                   , getRootQuery()->totaltime->tuplecount
                   , m_limitOfTuplesPerRootQuery.value()
      );
      breakPendingRootQuery();
    }
  }

  void TuplesQueryHandler::addInstrumentation( QueryDesc* _queryDesc ) const {
    // Add instrumentation to track query resources
    if ( _queryDesc->totaltime != nullptr ) {
      return;
    }
    /* Memory switching context is defined as static inline function which
     * cannot be mocked and in consequences it blocks unittests.
     */
#ifndef UNITTESTS
    MemoryContext oldCxt;
    oldCxt = MemoryContextSwitchTo(_queryDesc->estate->es_query_cxt);
#endif
    _queryDesc->totaltime = InstrAlloc(1, INSTRUMENT_ALL, true);
#ifndef UNITTESTS
    MemoryContextSwitchTo(oldCxt);
#endif
  }

} // namespace PsqlTools::PsqlUtils

