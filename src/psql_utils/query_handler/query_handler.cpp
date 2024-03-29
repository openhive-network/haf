#include "psql_utils/query_handler/query_handler.h"

namespace {
  PsqlTools::PsqlUtils::QueryHandler* g_topHandler{nullptr};

  void callErrorOnAllHandlers(const QueryDesc& _queryDesc) {
    for (
      auto* currentHandler = g_topHandler
      ; currentHandler
      ; currentHandler = currentHandler->previousHandler() ) {
      currentHandler->onError(_queryDesc);
    }
  }

  void startQueryHook(QueryDesc *_queryDesc, int _eflags) {
    assert( g_topHandler );

    for (
      auto *currentHandler = g_topHandler; currentHandler; currentHandler = currentHandler->previousHandler()) {
        PG_TRY();
        {
            currentHandler->onStartQuery( _queryDesc, _eflags );

            if (!currentHandler->previousHandler()) { // bottom handler
              if (currentHandler->originalStartHook()) {
                currentHandler->originalStartHook()( _queryDesc, _eflags );
              } else {
                standard_ExecutorStart( _queryDesc, _eflags );
              }
            }
        } //PG_TRY();
        PG_CATCH();
        {
          callErrorOnAllHandlers(*_queryDesc);
          PG_RE_THROW();
        }
        PG_END_TRY();
    } // for
  }

  }

  void endQueryHook(QueryDesc* _queryDesc) {
    assert( g_topHandler );

    for (
      auto* currentHandler = g_topHandler
      ; currentHandler
      ; currentHandler = currentHandler->previousHandler() ) {
        PG_TRY();
        {
          currentHandler->onEndQuery( _queryDesc );

          if (!currentHandler->previousHandler()) { // bottom handler
            if (currentHandler->originalEndHook()) {
              currentHandler->originalEndHook()( _queryDesc );
            } else {
              standard_ExecutorEnd( _queryDesc );
            }
          }
        } // PG_TRY();
        PG_CATCH();
        {
          callErrorOnAllHandlers(*_queryDesc);
          PG_RE_THROW();
        }
        PG_END_TRY();
    } // for
  }

  void onRunQueryHook(QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once) {
    assert( g_topHandler );

    for (
      auto* currentHandler = g_topHandler
      ; currentHandler
      ; currentHandler = currentHandler->previousHandler() ) {
      PG_TRY();
      {
        currentHandler->onRunQuery( _queryDesc, _direction, _count, _execute_once );

        if (!currentHandler->previousHandler()) { // bottom handler
          if (currentHandler->originalRunHook()) {
            currentHandler->originalRunHook()( _queryDesc, _direction, _count, _execute_once );
          } else {
            standard_ExecutorRun( _queryDesc, _direction, _count, _execute_once );
          }
        }
      }
      PG_CATCH();
      {
        callErrorOnAllHandlers(*_queryDesc);
        PG_RE_THROW();
      }
      PG_END_TRY();
    } // for
  }

  void onFinishQueryHook(QueryDesc* _queryDesc) {
    assert( g_topHandler );

    for (
      auto* currentHandler = g_topHandler
      ; currentHandler
      ; currentHandler = currentHandler->previousHandler() ) {
      PG_TRY();
      {
        currentHandler->onFinishQuery( _queryDesc );

        if (!currentHandler->previousHandler()) { // bottom handler
          if (currentHandler->originalFinishHook()) {
            currentHandler->originalFinishHook()( _queryDesc );
          } else {
            standard_ExecutorFinish( _queryDesc );
          }
        }
      }
      PG_CATCH();
        {
          callErrorOnAllHandlers(*_queryDesc);
          PG_RE_THROW();
        }
      PG_END_TRY();
    } // for
  }

namespace PsqlTools::PsqlUtils {
  QueryHandler::QueryHandler() {
    m_originalStarExecutorHook = ExecutorStart_hook;
    m_originalEndExecutorHook = ExecutorEnd_hook;
    m_originalRunExecutorHook = ExecutorRun_hook;
    m_originalFinishExecutorHook = ExecutorFinish_hook;
    ExecutorStart_hook = startQueryHook;
    ExecutorEnd_hook = endQueryHook;
    ExecutorRun_hook = onRunQueryHook;
    ExecutorFinish_hook = onFinishQueryHook;

    m_previousHandler = g_topHandler;
    g_topHandler = this;
  }

  QueryHandler::~QueryHandler() {
    // we can remove only top handler
    assert( g_topHandler == this );

    ExecutorStart_hook = m_originalStarExecutorHook;
    ExecutorEnd_hook =  m_originalEndExecutorHook;
    ExecutorRun_hook = m_originalRunExecutorHook;
    ExecutorFinish_hook = m_originalFinishExecutorHook;

    g_topHandler = m_previousHandler;
  }

  QueryHandler*
  QueryHandler::previousHandler()  {
      return m_previousHandler;
  }

  bool
  QueryHandler::isQueryCancelPending() {
    return QueryCancelPending;
  }

  void
  QueryHandler::breakPendingRootQuery() {
    StatementCancelHandler(0);
  }

  void
  QueryHandler::onError(const QueryDesc& _queryDesc) {
    LOG_DEBUG( "Error during processing a query %s", _queryDesc.sourceText );
  }
} // namespace PsqlTools::PsqlUtils


