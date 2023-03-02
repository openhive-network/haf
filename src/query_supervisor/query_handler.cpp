#include "query_handler.h"

namespace PsqlTools::QuerySupervisor {
  class QueryHandler::Impl {
  public:
    Impl(QueryHandler *_parent);
    ~Impl() = default;

    void onStartQuery(QueryDesc *_queryDesc, int _eflags);
    void onEndQuery(QueryDesc *_queryDesc);

    ExecutorStart_hook_type m_originalStarExecutorHook = nullptr;
    ExecutorEnd_hook_type m_originalEndExecutorHook = nullptr;

  private:
    QueryHandler* m_parent = nullptr;
  };

  QueryHandler::Impl::Impl(QueryHandler *_parent) {
    assert(_parent);
    m_parent = _parent;
  }

  void QueryHandler::Impl::onStartQuery(QueryDesc *_queryDesc, int _eflags) {
    assert(m_parent);
    m_parent->onStartQuery(_queryDesc, _eflags);

    if (m_originalStarExecutorHook) {
      return m_originalStarExecutorHook( _queryDesc, _eflags );
    }
    return standard_ExecutorStart( _queryDesc, _eflags );
  }

  void QueryHandler::Impl::onEndQuery(QueryDesc *_queryDesc) {
    assert(m_parent);
    m_parent->onEndQuery(_queryDesc);

    if (m_originalEndExecutorHook) {
      return m_originalEndExecutorHook( _queryDesc );
    }
    return standard_ExecutorEnd( _queryDesc );
  }
} // namespace PsqlTools::QuerySupervisor

namespace {
  void startQueryHook( QueryDesc *_queryDesc, int _eflags ) {
    PsqlTools::QuerySupervisor::QueryHandler::getImpl().onStartQuery(_queryDesc,_eflags);
  }

  void endQueryHook( QueryDesc *_queryDesc ) {
    PsqlTools::QuerySupervisor::QueryHandler::getImpl().onEndQuery(_queryDesc);
  }
} //namespace


namespace PsqlTools::QuerySupervisor {
  QueryHandler::QueryHandler() {
    m_impl = std::make_unique< Impl >(this);
    m_impl->m_originalStarExecutorHook = ExecutorStart_hook;
    m_impl->m_originalEndExecutorHook = ExecutorEnd_hook;
    ExecutorStart_hook = startQueryHook;
    ExecutorEnd_hook = endQueryHook;
  }

  QueryHandler::~QueryHandler() {
    ExecutorStart_hook = nullptr;
    ExecutorEnd_hook = nullptr;
  }

  std::unique_ptr< QueryHandler > QueryHandler::m_instance = nullptr;
} // namespace PsqlTools::QuerySupervisor


