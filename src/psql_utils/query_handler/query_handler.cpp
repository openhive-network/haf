#include "include/psql_utils/query_handler/query_handler.h"

namespace PsqlTools::PsqlUtils {
  class QueryHandler::Impl {
  public:
    Impl(QueryHandler *_parent);
    ~Impl() = default;

    void onStartQuery(QueryDesc *_queryDesc, int _eflags);
    void onEndQuery(QueryDesc *_queryDesc);
    void onRunQuery( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once );
    void onFinishQuery( QueryDesc* _queryDesc );

    void onCheckQueryResources();

    void startPeriodicTimer( const std::chrono::milliseconds& _period );
    void stopPeriodicTimer();
    bool isPeriodicTimerPending() const;
    bool isPeriodicTimerInitialized() const { return m_periodicTimeout != USER_TIMEOUT; }

    ExecutorStart_hook_type m_originalStarExecutorHook = nullptr;
    ExecutorEnd_hook_type m_originalEndExecutorHook = nullptr;
    ExecutorRun_hook_type m_originalRunExecutorHook = nullptr;
    ExecutorFinish_hook_type m_originalFinishExecutorHook = nullptr;

  private:
    QueryHandler* m_parent = nullptr;
    TimeoutId m_periodicTimeout{USER_TIMEOUT};
    bool m_isPeriodicTimeoutPending{false};
    std::chrono::milliseconds m_timeoutPeriod;
  };

  QueryHandler::Impl::Impl(QueryHandler *_parent) {
    assert(_parent);
    m_parent = _parent;
  }

  namespace {
    void startQueryHook(QueryDesc *_queryDesc, int _eflags) {
      PsqlTools::PsqlUtils::QueryHandler::getImpl().onStartQuery(_queryDesc, _eflags);
    }
  } // namespace

  void QueryHandler::Impl::onStartQuery(QueryDesc *_queryDesc, int _eflags) {
    assert(m_parent);
    m_parent->onStartQuery(_queryDesc, _eflags);

    if (m_originalStarExecutorHook) {
      return m_originalStarExecutorHook( _queryDesc, _eflags );
    }
    return standard_ExecutorStart( _queryDesc, _eflags );
  }

  namespace {
    void endQueryHook(QueryDesc *_queryDesc) {
      PsqlTools::PsqlUtils::QueryHandler::getImpl().onEndQuery(_queryDesc);
    }
  } // namespace

  void QueryHandler::Impl::onEndQuery(QueryDesc *_queryDesc) {
    assert(m_parent);
    m_parent->onEndQuery(_queryDesc);

    if (m_originalEndExecutorHook) {
      return m_originalEndExecutorHook( _queryDesc );
    }
    return standard_ExecutorEnd( _queryDesc );
  }

  namespace {
    void onRunQueryHook(QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once) {
      PsqlTools::PsqlUtils::QueryHandler::getImpl().onRunQuery( _queryDesc, _direction, _count, _execute_once );
    }
  } //namespace

  void QueryHandler::Impl::onRunQuery( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {
    assert(m_parent);
    m_parent->onRunQuery(_queryDesc);

    if ( m_originalRunExecutorHook ) {
      m_originalRunExecutorHook( _queryDesc, _direction, _count, _execute_once );
    }

    standard_ExecutorRun(_queryDesc, _direction, _count, _execute_once );
  }

  namespace {
    void onFinishQueryHook(QueryDesc* _queryDesc) {
      PsqlTools::PsqlUtils::QueryHandler::getImpl().onFinishQuery(_queryDesc);
    }
  }

  void QueryHandler::Impl::onFinishQuery( QueryDesc* _queryDesc ) {
    assert(m_parent);
    m_parent->onFinishQuery( _queryDesc );

    if ( m_originalFinishExecutorHook ) {
      m_originalFinishExecutorHook(_queryDesc);
    }

    standard_ExecutorFinish( _queryDesc );
  }

  void QueryHandler::Impl::onCheckQueryResources() {
    assert( m_parent );
    assert( isPeriodicTimerInitialized() );
    m_parent->onPeriodicCheck();
    if ( isPeriodicTimerPending() ) {
      enable_timeout_after( m_periodicTimeout, m_timeoutPeriod.count() );
    }
  }

  namespace {
    void timeoutHook() {
      PsqlTools::PsqlUtils::QueryHandler::getImpl().onCheckQueryResources();
    }
  } // namespace

  void QueryHandler::Impl::startPeriodicTimer( const std::chrono::milliseconds& _period ) {
    m_timeoutPeriod = _period;
    m_isPeriodicTimeoutPending = true;

    if ( !isPeriodicTimerInitialized() ) {
      // no worries about fail of registration because pg will terminate backend
      m_periodicTimeout = RegisterTimeout(m_periodicTimeout, timeoutHook);
    }

    enable_timeout_after( m_periodicTimeout, _period.count() );
  }

  void QueryHandler::Impl::stopPeriodicTimer() {
    disable_timeout( m_periodicTimeout, true );
    m_isPeriodicTimeoutPending = false;
  }

  bool QueryHandler::Impl::isPeriodicTimerPending() const {
    return m_isPeriodicTimeoutPending;
  }
} // namespace PsqlTools::PsqlUtils


namespace PsqlTools::PsqlUtils {
  QueryHandler::QueryHandler() {
    m_impl = std::make_unique< Impl >(this);
    m_impl->m_originalStarExecutorHook = ExecutorStart_hook;
    m_impl->m_originalEndExecutorHook = ExecutorEnd_hook;
    m_impl->m_originalRunExecutorHook = ExecutorRun_hook;
    m_impl->m_originalFinishExecutorHook = ExecutorFinish_hook;
    ExecutorStart_hook = startQueryHook;
    ExecutorEnd_hook = endQueryHook;
    ExecutorRun_hook = onRunQueryHook;
    ExecutorFinish_hook = onFinishQueryHook;
  }

  QueryHandler::~QueryHandler() {
    ExecutorStart_hook = m_impl->m_originalStarExecutorHook;
    ExecutorEnd_hook =  m_impl->m_originalEndExecutorHook;
    ExecutorRun_hook = m_impl->m_originalRunExecutorHook;
    ExecutorFinish_hook = m_impl->m_originalFinishExecutorHook;
  }

  void
  QueryHandler::onStartQuery( QueryDesc* _queryDesc, int _eflags ) {

  }

  void
  QueryHandler::onEndQuery( QueryDesc* _queryDesc ) {

  }

  void QueryHandler::startPeriodicCheck( const std::chrono::milliseconds& _period ) {
    return getImpl().startPeriodicTimer( _period );
  }

  void QueryHandler::stopPeriodicCheck() {
    return getImpl().stopPeriodicTimer();
  }

  bool QueryHandler::isPeriodicTimerPending() const {
    return getImpl().isPeriodicTimerPending();
  }

  std::unique_ptr< QueryHandler > QueryHandler::m_instance = nullptr;
} // namespace PsqlTools::PsqlUtils


