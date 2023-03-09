#include <boost/test/unit_test.hpp>

#include "include/psql_utils/query_handler/timeout_query_handler.h"

#include "mock/postgres_mock.hpp"

struct timeout_query_handler_fixture
{
  timeout_query_handler_fixture() {
    ExecutorStart_hook = executorStartHook;
    ExecutorRun_hook = executorRunHook;
    ExecutorFinish_hook = executorFinishHook;
    ExecutorEnd_hook = executorEndHook;

    m_postgres_mock = PostgresMock::create_and_get();
  }
  ~timeout_query_handler_fixture() {
    ExecutorStart_hook = nullptr;
    ExecutorRun_hook = nullptr;
    ExecutorFinish_hook = nullptr;
    ExecutorEnd_hook = nullptr;

    if ( PsqlTools::PsqlUtils::TimeoutQueryHandler::isInitialized() ) {
      EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(1);
      PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>();
    }
  }

  std::shared_ptr<PostgresMock> m_postgres_mock;
};

using namespace std::chrono_literals;

BOOST_FIXTURE_TEST_SUITE( start_query_handler, timeout_query_handler_fixture )

  BOOST_AUTO_TEST_CASE( initialization ) {
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ) ).Times( 1 );

    PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>( 1s );

    BOOST_ASSERT( TimeoutQueryHandler::isInitialized() );

    // check if handlers are changed
    BOOST_ASSERT( ExecutorStart_hook != executorStartHook );
    BOOST_ASSERT( ExecutorRun_hook != executorRunHook );
    BOOST_ASSERT( ExecutorFinish_hook != executorFinishHook );
    BOOST_ASSERT( ExecutorEnd_hook != executorEndHook );
  }

  BOOST_AUTO_TEST_CASE( deinitialization ) {
    const auto EXPECTED_TIMER_ID = static_cast< TimeoutId >( USER_TIMEOUT + 1 );
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ) )
      .Times( 1 )
      .WillOnce( ::testing::Return( EXPECTED_TIMER_ID ) )
    ;
    PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>( 1s );

    EXPECT_CALL( *m_postgres_mock, disable_timeout( EXPECTED_TIMER_ID, true ) ).Times(1);

    PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>();

    // check if handlers are restored
    BOOST_ASSERT( ExecutorStart_hook == executorStartHook );
    BOOST_ASSERT( ExecutorRun_hook == executorRunHook );
    BOOST_ASSERT( ExecutorFinish_hook == executorFinishHook );
    BOOST_ASSERT( ExecutorEnd_hook == executorEndHook );
  }

BOOST_AUTO_TEST_SUITE_END()
