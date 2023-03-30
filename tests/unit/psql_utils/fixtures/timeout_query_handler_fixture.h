#pragma once

#include "mock/gmock_fixture.hpp"

#include "psql_utils/query_handler/timeout_query_handler.h"

#include "mock/postgres_mock.hpp"

#include <chrono>

namespace Fixtures {

  struct TimeoutQueryHandlerFixture : public GmockFixture {
    TimeoutQueryHandlerFixture();

    ~TimeoutQueryHandlerFixture();

    void moveToPendingRootQuery();

    std::unique_ptr<QueryDesc> m_rootQuery;
    std::unique_ptr<QueryDesc> m_subQuery;
    static const auto m_expected_timer_id = static_cast< TimeoutId >( USER_TIMEOUT + 1 );
    timeout_handler_proc m_timoutHandler = nullptr;

    std::shared_ptr< PsqlTools::PsqlUtils::TimeoutQueryHandler > m_unitUnderTest;
  };


  inline void TimeoutQueryHandlerFixture::moveToPendingRootQuery() {
    using namespace  std::chrono_literals;
    const auto flags = 0;

    ON_CALL( *m_postgres_mock, RegisterTimeout ).WillByDefault(
      [this](TimeoutId _id, timeout_handler_proc _handler) {
        m_timoutHandler = _handler;
        return m_expected_timer_id;
      }
    );
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ))
      .Times( 1 );
    EXPECT_CALL( *m_postgres_mock, enable_timeout_after( m_expected_timer_id, 1000)).Times( 1 );
    if (ExecutorStart_hook) {
      EXPECT_CALL( *m_postgres_mock, executorStartHook( m_rootQuery.get(), flags )).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( m_rootQuery.get(), flags )).Times( 1 );
    }

    m_unitUnderTest = std::make_shared< PsqlTools::PsqlUtils::TimeoutQueryHandler >( []{ return 1000ms; } );

    ExecutorStart_hook( m_rootQuery.get(), flags );
  }

} // namespace Fixtures
