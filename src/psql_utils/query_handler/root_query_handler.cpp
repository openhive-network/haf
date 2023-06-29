#include "psql_utils/query_handler/root_query_handler.hpp"

namespace PsqlTools::PsqlUtils {
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
    if ( isRootQuery( *_queryDesc ) && isRootQueryPending() ) {
      /* If we are here it means that pending root query was broken
       * and its finish was not passed to the handlers (what is a normal situation).
       * We are starting now a new root query, but we need
       * to inform the object about ending the previous one.
       */
      LOG_DEBUG( "New root query '%s' has started while the previous one '%s' is still in progress.", _queryDesc->sourceText, getRootQuery()->sourceText );
      endOfRootQuery();
    }


    if ( !isRootQueryPending() ) {
      m_rootQuery = _queryDesc;
      this->onRootQueryRun(_queryDesc, _direction, _count, _execute_once);
      return;
    }

    this->onSubQueryRun(_queryDesc, _direction, _count, _execute_once);
  }

  void RootQueryHandler::onFinishQuery( QueryDesc* _queryDesc ) {
    assert( isRootQueryPending() );

    if ( isPendingRootQuery( _queryDesc ) ) {
      this->onRootQueryFinish( _queryDesc );
      return;
    }
    onSubQueryFinish( _queryDesc );

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
    if ( m_rootQuery == nullptr )
      return;

    LOG_DEBUG( "End root query: %s", m_rootQuery->sourceText );
    m_rootQuery = nullptr;
  }

  bool
  RootQueryHandler::isRootQuery( const QueryDesc& _queryDesc ) const {
    // when there is an outer plan, for sure it is not a root
    if ( (_queryDesc.planstate) && outerPlan(_queryDesc.planstate) )
      return false;

    return _queryDesc.dest->mydest == DestNone
      || _queryDesc.dest->mydest == DestRemote
      || _queryDesc.dest->mydest == DestRemoteSimple;
    ;
  }

  QueryDesc*
  RootQueryHandler::getRootQuery() const {
    return m_rootQuery;
  }

} // namespace PsqlTools::PsqlUtils
