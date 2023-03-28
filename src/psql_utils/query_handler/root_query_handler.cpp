#include "psql_utils/query_handler/root_query_handler.hpp"

namespace PsqlTools::PsqlUtils {

  void RootQueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {
    if ( !isRootQueryPending() ) {
      LOG_DEBUG( "Start root query: %s", _queryDesc->sourceText );
      m_rootQuery = _queryDesc;
      this->onRootQueryStart(_queryDesc, _eflags);
      return;
    }

    this->onSubQueryStart(_queryDesc, _eflags);
  }

  void RootQueryHandler::onEndQuery( QueryDesc* _queryDesc ) {
    assert( isRootQueryPending() );

    if ( isPendingRootQuery( _queryDesc ) ) {
      this->onRootQueryEnd( _queryDesc );
      endOfRootQuery();
      return;
    }

    this->onSubQueryEnd( _queryDesc );
  }

  void RootQueryHandler::onRunQuery( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {
    assert( isRootQueryPending() );

    if ( isPendingRootQuery( _queryDesc ) ) {
      this->onRootQueryRun( _queryDesc, _direction, _count, _execute_once );
      return;
    }

    this->onSubQueryRun( _queryDesc, _direction, _count, _execute_once );
  }

  void RootQueryHandler::onFinishQuery( QueryDesc* _queryDesc ) {
    assert( isRootQueryPending() );

    if ( isPendingRootQuery( _queryDesc ) ) {
      this->onRootQueryFinish( _queryDesc );
      return;
    }

    this->onSubQueryFinish( _queryDesc );
  }


  bool
  RootQueryHandler::isPendingRootQuery(QueryDesc* _queryDesc) const {
    if ( _queryDesc == nullptr ) {
      return false;
    }

    return m_rootQuery == _queryDesc;
  }

  bool RootQueryHandler::isRootQueryPending() const {
    return m_rootQuery != nullptr;
  }

  void RootQueryHandler::endOfRootQuery() {
    assert( m_rootQuery );

    LOG_DEBUG( "End root query: %s", m_rootQuery->sourceText );
    m_rootQuery = nullptr;
  }

  QueryDesc*
  RootQueryHandler::getRootQuery() const {
    return m_rootQuery;
  }

} // namespace PsqlTools::PsqlUtils
