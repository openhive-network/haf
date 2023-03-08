#pragma once

#include "include/psql_utils/postgres_includes.hpp"

#include <cassert>
#include <chrono>
#include <memory>

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

      template< typename _Handler, typename... _Args >
      static void initialize(_Args... _args);

      template< typename _Handler, typename... _Args >
      static void deinitialize(_Args... _args);

    protected:
      QueryHandler();

      virtual void onStartQuery( QueryDesc* _queryDesc, int _eflags ) = 0;
      virtual void onEndQuery( QueryDesc* _queryDesc ) = 0;

      virtual void onRunQuery( QueryDesc* _queryDesc )  {}
      virtual void onFinishQuery( QueryDesc* _queryDesc )  {}
      virtual void onPeriodicCheck() {}

      // helpers to start periodic check
      void startPeriodicCheck( const std::chrono::milliseconds& _period );
      void stopPeriodicCheck();
      bool isPeriodicTimerPending() const;

    public:
      class Impl;
      std::unique_ptr< Impl > m_impl;
      static Impl& getImpl() { assert(m_instance && m_instance->m_impl ); return *m_instance->m_impl; }
    private:
      static std::unique_ptr<QueryHandler> m_instance;
  };

  template< typename _Handler, typename... _Args >
  inline void QueryHandler::initialize(_Args... _args) {
    static_assert( std::is_base_of_v< QueryHandler, _Handler >, "Handler is not derived from QueryHandler" );
    assert( m_instance == nullptr && "Query handler already initialized" );
    m_instance = std::make_unique< _Handler >(_args...);
  }

  template< typename _Handler, typename... _Args >
  inline void QueryHandler::deinitialize(_Args... _args) {
    static_assert( std::is_base_of_v< QueryHandler, _Handler >, "Handler is not derived from QueryHandler" );
    assert( m_instance != nullptr && "Query handler is not initialized" );
    m_instance.reset();
  }

} // namespace PsqlTools::PsqlUtils
