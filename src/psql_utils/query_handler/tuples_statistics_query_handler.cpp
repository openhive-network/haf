#include "psql_utils/query_handler/tuples_statistics_query_handler.hpp"

#include "psql_utils/logger.hpp"

#include <boost/scope_exit.hpp>


namespace PsqlTools::PsqlUtils {

  TuplesStatisticsQueryHandler::TuplesStatisticsQueryHandler()
  {
    resetStatistics();
    assert( m_statistics.size() == 5 ); // all Filter flags are in the map
  }

  void TuplesStatisticsQueryHandler::onRootQueryRun(QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {
    resetStatistics();
    addInstrumentation( _queryDesc );
  }

  void TuplesStatisticsQueryHandler::onSubQueryRun(QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {
    addInstrumentation( _queryDesc );
  }

  void TuplesStatisticsQueryHandler::onRootQueryFinish(QueryDesc* _queryDesc ) {
    assert( _queryDesc );

    updateStatistics( *_queryDesc );


    LOG_DEBUG( "Finish root query: %s with tuples:  %lf", _queryDesc->sourceText, _queryDesc->totaltime->tuplecount );
    if ( isQueryCancelPending() ) {
      return;
    }

    checkTuplesLimit();
  }

  void TuplesStatisticsQueryHandler::onSubQueryFinish(QueryDesc* _queryDesc ) {
    assert( _queryDesc );
    assert( _queryDesc->totaltime );

    updateStatistics( *_queryDesc );

    LOG_DEBUG( "Finish sub query: %s with tuples:  %lf", _queryDesc->sourceText, _queryDesc->totaltime->tuplecount );
    if ( isQueryCancelPending() ) {
      return;
    }

    checkTuplesLimit();
  }

  void TuplesStatisticsQueryHandler::onError( const QueryDesc& _queryDesc ) {
    resetStatistics();
    RootQueryHandler::onError(_queryDesc);
  }

  void TuplesStatisticsQueryHandler::checkTuplesLimit() {
    if ( breakQuery() ) {
      LOG_WARNING( "Query %s was broken because of tuples limit reached", getRootQuery()->sourceText );
      breakPendingRootQuery();
    }
  }

  void TuplesStatisticsQueryHandler::addInstrumentation(QueryDesc* _queryDesc ) const {
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

  bool TuplesStatisticsQueryHandler::breakQuery() const {
    return false;
  }

  TuplesStatisticsQueryHandler::SqlCommand
  TuplesStatisticsQueryHandler::cmdTypeToFilter( CmdType _cmd ) const {
    switch (_cmd) {
      case CMD_SELECT:
        return SqlCommand::SELECT;
      case CMD_DELETE:
        return SqlCommand::DELETE;
      case CMD_INSERT:
        return SqlCommand::INSERT;
      case CMD_UPDATE:
        return SqlCommand::UPDATE;
      default:
        return SqlCommand::OTHER;
    }
  }

  void
  TuplesStatisticsQueryHandler::updateStatistics( const QueryDesc& _queryDesc ) {
    assert( _queryDesc.totaltime );

    m_statistics[ cmdTypeToFilter( _queryDesc.operation ) ] += _queryDesc.totaltime->tuplecount;
    m_numberOfAllTuples += _queryDesc.totaltime->tuplecount;
  }

  void
  TuplesStatisticsQueryHandler::resetStatistics() {
    m_numberOfAllTuples = 0u;

    m_statistics = {
        {SqlCommand::SELECT, 0u }
      , {SqlCommand::UPDATE, 0u }
      , {SqlCommand::INSERT, 0u }
      , {SqlCommand::DELETE, 0}
      , {SqlCommand::OTHER,  0}
    };
  }

} // namespace PsqlTools::PsqlUtils

