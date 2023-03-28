#pragma once

#include "mock/gmock_fixture.hpp"

#include "psql_utils/query_handler/timeout_query_handler.h"

#include "mock/postgres_mock.hpp"

#include <chrono>

namespace Fixtures {

  struct TimeoutQueryHandlerFixture : public GmockFixture {
    TimeoutQueryHandlerFixture();

    ~TimeoutQueryHandlerFixture();

    template< typename _Handler, typename... _Args  >
    void moveToPendingRootQuery( _Args... _args );

    std::unique_ptr<QueryDesc> m_rootQuery;
    std::unique_ptr<QueryDesc> m_subQuery;
    static const auto m_expected_timer_id = static_cast< TimeoutId >( USER_TIMEOUT + 1 );
    const std::chrono::milliseconds m_timeout{1000};
    timeout_handler_proc m_timoutHandler = nullptr;
  };

  template< typename _Handler, typename... _Args >
  inline void TimeoutQueryHandlerFixture::moveToPendingRootQuery( _Args... _args ) {
    const auto flags = 0;

    ON_CALL( *m_postgres_mock, RegisterTimeout ).WillByDefault(
      [this](TimeoutId _id, timeout_handler_proc _handler) {
        m_timoutHandler = _handler;
        return m_expected_timer_id;
      }
    );
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ))
      .Times( 1 );
    EXPECT_CALL( *m_postgres_mock, enable_timeout_after( m_expected_timer_id, m_timeout.count())).Times( 1 );
    if (ExecutorStart_hook) {
      EXPECT_CALL( *m_postgres_mock, executorStartHook( m_rootQuery.get(), flags )).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( m_rootQuery.get(), flags )).Times( 1 );
    }

    PsqlTools::PsqlUtils::QueryHandler::initialize<_Handler>( _args... );

    ExecutorStart_hook( m_rootQuery.get(), flags );
  }

} // namespace Fixtures
