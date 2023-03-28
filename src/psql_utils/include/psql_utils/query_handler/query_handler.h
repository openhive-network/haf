#pragma once

#include "include/exceptions.hpp"
#include "psql_utils/postgres_includes.hpp"

#include <cassert>
#include <chrono>
#include <memory>
#include <optional>

namespace PsqlTools::PsqlUtils {
  /**
   * Base class for queries handlers - classes which can observe and break queries execution
   * The class overwrite PostgreSQL executor hooks to its own hooks which call C++ base virtual methods
   * Only one object of the class can exists, thus to ensure that only one hook implementation is in use
   * in a process.
   */
  class QueryHandler {
    public:
      virtual ~QueryHandler();
      QueryHandler( const QueryHandler& ) = delete;
      QueryHandler( const QueryHandler&& ) = delete;
      QueryHandler& operator=( const QueryHandler& ) = delete;
      QueryHandler& operator=( QueryHandler&& ) = delete;

      /**
      * Methods are called when the executor starts and ends executes a query (exactly a statement).
      * Warning! Postgres function call is treated as one statement, and statements in a function body
      * are treated as separated statements and each of them are started and ended by the executor separately.
      * Original hooks are started after these methods
      */
      virtual void onStartQuery( QueryDesc* _queryDesc, int _eflags ) {}
      virtual void onEndQuery( QueryDesc* _queryDesc ) {}

      /**
      * Methods are called when the executor runs and  finish executes a query (exactly a statement).
      * PostgreSQL added this stage for some query resources initialization, especially a query instrumentation.
      * Methods are not 'poor virtual' because not every handler will use them
      * Original hooks are started after these methods
      */
      virtual void onRunQuery( QueryDesc* _queryDesc, ScanDirection _direction, uint64 _count, bool _execute_once ) {}
      virtual void onFinishQuery( QueryDesc* _queryDesc ) {}

      QueryHandler* previousHandler();
      ExecutorStart_hook_type originalStartHook() const { return m_originalStarExecutorHook; }
      ExecutorEnd_hook_type originalEndHook() const { return m_originalEndExecutorHook; }
      ExecutorRun_hook_type originalRunHook() const { return m_originalRunExecutorHook; }
      ExecutorFinish_hook_type originalFinishHook() const { return m_originalFinishExecutorHook; }

      // returns true is canceling query is in progress- is scheduled but not executed yet
      static bool isQueryCancelPending();

    protected:
      QueryHandler();

      static void breakPendingRootQuery();

    private:
      ExecutorStart_hook_type m_originalStarExecutorHook = nullptr;
      ExecutorEnd_hook_type m_originalEndExecutorHook = nullptr;
      ExecutorRun_hook_type m_originalRunExecutorHook = nullptr;
      ExecutorFinish_hook_type m_originalFinishExecutorHook = nullptr;

      QueryHandler* m_previousHandler = nullptr;
  };
} // namespace PsqlTools::PsqlUtils
