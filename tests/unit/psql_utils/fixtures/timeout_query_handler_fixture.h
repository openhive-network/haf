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
    std::unique_ptr<DestReceiver> m_rootDestReceiver;
    std::unique_ptr<QueryDesc> m_subQuery;
    std::unique_ptr<DestReceiver> m_subDestReceiver;
    static const auto m_expected_timer_id = static_cast< TimeoutId >( USER_TIMEOUT + 1 );
    timeout_handler_proc m_timoutHandler = nullptr;

    std::shared_ptr< PsqlTools::PsqlUtils::TimeoutQueryHandler > m_unitUnderTest;
  };


  inline void TimeoutQueryHandlerFixture::moveToPendingRootQuery() {
    using namespace  std::chrono_literals;
    using namespace ::testing;

    ON_CALL( *m_postgres_mock, RegisterTimeout ).WillByDefault(
      [this](TimeoutId _id, timeout_handler_proc _handler) {
        m_timoutHandler = _handler;
        return m_expected_timer_id;
      }
    );
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ))
      .Times( 1 );
    EXPECT_CALL( *m_postgres_mock, enable_timeout_after( m_expected_timer_id, 1000)).Times( AtLeast(1) );
    if (ExecutorRun_hook) {
      EXPECT_CALL( *m_postgres_mock, executorRunHook( m_rootQuery.get(), _, _, _ )).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorRun( m_rootQuery.get(), _, _, _ )).Times( 1 );
    }

    m_unitUnderTest = std::make_shared< PsqlTools::PsqlUtils::TimeoutQueryHandler >( []{ return 1000ms; } );

    ExecutorRun_hook( m_rootQuery.get(), BackwardScanDirection, 0, true );
  }

} // namespace Fixtures
