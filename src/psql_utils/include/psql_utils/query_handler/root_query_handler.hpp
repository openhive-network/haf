#pragma once

#include "psql_utils/query_handler/query_handler.h"

namespace PsqlTools::PsqlUtils {

  /**
   *  base class for handlers which need to distinguish between root and sub queries
   *  root query - top level query executed by connection i.e function call
   *  sub query - non top level query, i.e a statement from called function
   */
  class RootQueryHandler : protected QueryHandler {
  public:
    bool isRootQueryPending() const;

  protected:
    RootQueryHandler() = default;
    ~RootQueryHandler() override = default;

    virtual void onRootQueryStart( QueryDesc* _queryDesc, int _eflags ) {}
    virtual void onRootQueryEnd( QueryDesc* _queryDesc ) {}
    virtual void onRootQueryRun(  QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {}
    virtual void onRootQueryFinish( QueryDesc* _queryDesc ) {}

    virtual void onSubQueryStart( QueryDesc* _queryDesc, int _eflags ) {}
    virtual void onSubQueryEnd( QueryDesc* _queryDesc ) {}
    virtual void onSubQueryRun(  QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {}
    virtual void onSubQueryFinish( QueryDesc* _queryDesc ) {}
    void onError( const QueryDesc& _queryDesc ) override;

    QueryDesc* getRootQuery() const;

  private:
    void onStartQuery( QueryDesc* _queryDesc, int _eflags ) override;
    void onEndQuery( QueryDesc* _queryDesc ) override;
    void onRunQuery( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) override;
    void onFinishQuery( QueryDesc* _queryDesc ) override;

    bool isPendingRootQuery(QueryDesc* _queryDesc) const;
    void endOfRootQuery();
  private:
    QueryDesc* m_rootQuery = nullptr;
  };

} // namespace PsqlTools::PsqlUtils