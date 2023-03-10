#include <boost/test/unit_test.hpp>

#include "include/psql_utils/query_handler/timeout_query_handler.h"

#include "mock/postgres_mock.hpp"

using namespace std::chrono_literals;

struct timeout_query_handler_fixture
{
  timeout_query_handler_fixture() {
    ExecutorStart_hook = executorStartHook;
    ExecutorRun_hook = executorRunHook;
    ExecutorFinish_hook = executorFinishHook;
    ExecutorEnd_hook = executorEndHook;

    QueryCancelPending = false;

    m_postgres_mock = PostgresMock::create_and_get();
    m_rootQuery = std::make_unique< QueryDesc >();
    m_subQuery = std::make_unique< QueryDesc >();
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

  void moveToPendingRootQuery() {
    const auto flags = 0;

    ON_CALL(*m_postgres_mock, RegisterTimeout).WillByDefault(
      [this](TimeoutId _id, timeout_handler_proc _handler) { m_timoutHandler = _handler; return m_expected_timer_id;}
      );
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ) )
      .Times(1);
    EXPECT_CALL( *m_postgres_mock, enable_timeout_after( m_expected_timer_id, m_timeout.count() ) ).Times(1);
    if ( ExecutorStart_hook ) {
      EXPECT_CALL( *m_postgres_mock, executorStartHook( m_rootQuery.get(), flags )).Times(1);
    }
    else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( m_rootQuery.get(), flags )).Times(1);
    }

    PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>( m_timeout );

    ExecutorStart_hook( m_rootQuery.get(), flags );
  }

  std::shared_ptr<PostgresMock> m_postgres_mock;
  std::unique_ptr<QueryDesc> m_rootQuery;
  std::unique_ptr<QueryDesc> m_subQuery;
  static const auto m_expected_timer_id = static_cast< TimeoutId >( USER_TIMEOUT + 1 );
  const std::chrono::milliseconds m_timeout = 1s;
  timeout_handler_proc m_timoutHandler = nullptr;
};


BOOST_FIXTURE_TEST_SUITE( start_query_handler, timeout_query_handler_fixture )

  BOOST_AUTO_TEST_CASE( initialization ) {
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ) ).Times( 1 );

    PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>( 1s );

    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isInitialized() );

    // check if handlers are changed
    BOOST_ASSERT( ExecutorStart_hook != executorStartHook );
    BOOST_ASSERT( ExecutorRun_hook != executorRunHook );
    BOOST_ASSERT( ExecutorFinish_hook != executorFinishHook );
    BOOST_ASSERT( ExecutorEnd_hook != executorEndHook );
  }

  BOOST_AUTO_TEST_CASE( deinitialization ) {
    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ) )
      .Times( 1 )
      .WillOnce( ::testing::Return( m_expected_timer_id ) )
    ;
    PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>( 1s );

    EXPECT_CALL( *m_postgres_mock, disable_timeout( m_expected_timer_id, true ) ).Times(1);

    PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>();

    // check if handlers are restored
    BOOST_ASSERT( ExecutorStart_hook == executorStartHook );
    BOOST_ASSERT( ExecutorRun_hook == executorRunHook );
    BOOST_ASSERT( ExecutorFinish_hook == executorFinishHook );
    BOOST_ASSERT( ExecutorEnd_hook == executorEndHook );

    BOOST_ASSERT( !PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( star_query_previous_hook_set ) {
    // GIVEN
    auto rootQuery = std::make_unique< QueryDesc >();
    const auto flags = 0;

    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ) )
      .Times( 1 )
      .WillOnce( ::testing::Return( m_expected_timer_id ) )
    ;
    const std::chrono::milliseconds timeout = 1s;
    PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>( timeout );

    // THEN
    // setup timeout
    EXPECT_CALL( *m_postgres_mock, enable_timeout_after( m_expected_timer_id, timeout.count() ) ).Times(1);
    // call previous hook
    EXPECT_CALL( *m_postgres_mock, executorStartHook( rootQuery.get(), flags ) ).Times(1);
    // previous hook is responsible for calling standard executor
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( m_rootQuery.get(), flags ) ).Times(0);

    // WHEN
    // pretend executor hook call
    ExecutorStart_hook( rootQuery.get(), flags );

    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( star_query_previous_hook_not_set ) {
    // GIVEN
    ExecutorStart_hook = nullptr;
    auto rootQuery = std::make_unique< QueryDesc >();
    const auto flags = 0;

    EXPECT_CALL( *m_postgres_mock, RegisterTimeout( USER_TIMEOUT, testing::_ ) )
      .Times( 1 )
      .WillOnce( ::testing::Return( m_expected_timer_id ) )
      ;
    const std::chrono::milliseconds timeout = 1s;
    PsqlTools::PsqlUtils::QueryHandler::initialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>( timeout );

    // THEN
    // setup timeout
    EXPECT_CALL( *m_postgres_mock, enable_timeout_after( m_expected_timer_id, timeout.count() ) ).Times(1);
    EXPECT_CALL( *m_postgres_mock, executorStartHook( rootQuery.get(), flags ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( rootQuery.get(), flags ) ).Times(1);

    // WHEN
    // pretend executor hook call
    ExecutorStart_hook( rootQuery.get(), flags );

    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }
  BOOST_AUTO_TEST_CASE( end_query_previous_hook_not_set ) {
    // GIVEN
    ExecutorEnd_hook = nullptr;
    moveToPendingRootQuery();

    // THEN PART 1
    // setup timeout
    EXPECT_CALL( *m_postgres_mock, disable_timeout( m_expected_timer_id, false ) ).Times(1);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorEnd( m_rootQuery.get() ) ).Times(1);

    // WHEN
    // pretend executor hook call
    ExecutorEnd_hook( m_rootQuery.get() );

    // THEN PART 2
    BOOST_ASSERT( !PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( end_root_query_previous_hook_set ) {
    // GIVEN
    moveToPendingRootQuery();

    // THEN PART 1
    // setup timeout
    EXPECT_CALL( *m_postgres_mock, disable_timeout( m_expected_timer_id, false  ) ).Times(1);
    EXPECT_CALL( *m_postgres_mock, executorEndHook( m_rootQuery.get() ) ).Times(1);
    // do not call standard end, previously set hook is responsible for this
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorEnd( ::testing::_ ) ).Times(0);

    // WHEN
    // pretend executor hook call
    ExecutorEnd_hook( m_rootQuery.get() );

    // THEN PART 2
    BOOST_ASSERT( !PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( end_root_query_sub_query ) {
    // GIVEN
    moveToPendingRootQuery();

    // THEN PART 1
    // do not disable timer when only subquery was ended
    EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, executorEndHook( m_subQuery.get() ) ).Times(1);
    // do not call standard end, previously set hook is responsible for this
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorEnd( ::testing::_ ) ).Times(0);

    // WHEN
    // pretend executor hook call
    ExecutorEnd_hook( m_subQuery.get() );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( end_root_query_sub_query_handler_not_set ) {
    // GIVEN
    ExecutorEnd_hook = nullptr;
    moveToPendingRootQuery();

    // THEN PART 1
    // do not disable timer when only subquery was ended
    EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorEnd( m_subQuery.get() ) ).Times(1);

    // WHEN
    // pretend executor hook call
    ExecutorEnd_hook( m_subQuery.get() );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( start_root_query_sub_query ) {
    // GIVEN
    const int subQueryFlags = 0;
    moveToPendingRootQuery();

    // THEN PART 1
    // do not disable timer when only subquery was ended
    EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, executorStartHook( m_subQuery.get(), subQueryFlags ) ).Times(1);
    // do not call standard end, previously set hook is responsible for this
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( ::testing::_, ::testing::_ ) ).Times(0);

    // WHEN
    // pretend executor hook call
    ExecutorStart_hook( m_subQuery.get(), subQueryFlags );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( start_root_query_sub_query_handler_not_set ) {
    // GIVEN
    const int subQueryFlags = 0;
    ExecutorStart_hook = nullptr;
    moveToPendingRootQuery();

    // THEN PART 1
    // do not disable timer when only subquery was ended
    EXPECT_CALL( *m_postgres_mock, enable_timeout_after( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( m_subQuery.get(), subQueryFlags ) ).Times(1);

    // WHEN
    // pretend executor hook call
    ExecutorStart_hook( m_subQuery.get(), subQueryFlags );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( run_query_previous_hook_not_set ) {
    // GIVEN
    ExecutorRun_hook = nullptr;
    const ScanDirection direction = BackwardScanDirection;
    const uint64 count = 15;
    const bool executeOnce = true;
    moveToPendingRootQuery();

    // THEN PART 1
    // setup timeout
    EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorRun( m_rootQuery.get(), direction, count, executeOnce ) ).Times(1);

    // WHEN
    // pretend executor hook call
    ExecutorRun_hook( m_rootQuery.get(), direction, count, executeOnce );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( run_query_previous_hook_set ) {
    // GIVEN
    const ScanDirection direction = BackwardScanDirection;
    const uint64 count = 15;
    const bool executeOnce = true;
    moveToPendingRootQuery();

    // THEN PART 1
    EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, executorRunHook( m_rootQuery.get(), direction, count, executeOnce ) ).Times(1);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorRun( ::testing::_, ::testing::_, ::testing::_, ::testing::_ ) ).Times(0);

    // WHEN
    // pretend executor hook call
    ExecutorRun_hook( m_rootQuery.get(), direction, count, executeOnce );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( finish_query_previous_hook_not_set ) {
    // GIVEN
    ExecutorFinish_hook = nullptr;
    moveToPendingRootQuery();

    // THEN PART 1
    // setup timeout
    EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorFinish( m_rootQuery.get() ) ).Times(1);

    // WHEN
    // pretend executor hook call
    ExecutorFinish_hook( m_rootQuery.get() );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( finish_query_previous_hook_set ) {
    // GIVEN
    moveToPendingRootQuery();

    // THEN PART 1
    EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, executorFinishHook( m_rootQuery.get() ) ).Times(1);
    EXPECT_CALL( *m_postgres_mock, standard_ExecutorFinish( ::testing::_ ) ).Times(0);

    // WHEN
    // pretend executor hook call
    ExecutorFinish_hook( m_rootQuery.get() );

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( timeout_handler ) {
    // GIVEN
    moveToPendingRootQuery();
    BOOST_ASSERT( m_timoutHandler != nullptr );

    // THEN PART 1
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( ::testing::_ ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our timeout handler
    m_timoutHandler();

    // THEN PART 2
    BOOST_ASSERT( !PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_SUITE_END()
