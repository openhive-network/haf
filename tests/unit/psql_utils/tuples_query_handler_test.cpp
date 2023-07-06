#include <boost/test/unit_test.hpp>
#include "fixtures/tuples_query_handler_fixture.h"

#include "psql_utils/query_handler/tuples_query_handler.h"

#include <chrono>

using namespace std::chrono_literals;

BOOST_FIXTURE_TEST_SUITE( tuples_query_handler, Fixtures::TuplesQueryHandlerFixture )

  BOOST_AUTO_TEST_CASE( tuples_less_than_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );

    m_rootQuery->totaltime->tuplecount = tuplesLimit - 10;

    // THEN PART 1
    // query cannot be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(0);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());
  }

  BOOST_AUTO_TEST_CASE( tuples_eq_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );

    m_rootQuery->totaltime->tuplecount = tuplesLimit;

    // THEN PART 1
    // query cannot be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(0);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());
  }

  BOOST_AUTO_TEST_CASE( tuples_gt_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );

    m_rootQuery->totaltime->tuplecount = tuplesLimit + 10;

    // THEN PART 1
    // query must be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());
  }

  BOOST_AUTO_TEST_CASE( subquery_tuples_less_than_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );

    m_rootQuery->totaltime->tuplecount = tuplesLimit - 10;
    Instrumentation subQueryInstrumentation;
    m_subQuery->totaltime = &subQueryInstrumentation;

    // THEN PART 1
    // query cannot be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, InstrAggNode( m_rootQuery->totaltime, m_subQuery->totaltime ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_subQuery.get());
  }

  BOOST_AUTO_TEST_CASE( subquery_tuples_eq_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );

    m_rootQuery->totaltime->tuplecount = tuplesLimit;
    Instrumentation subQueryInstrumentation;
    m_subQuery->totaltime = &subQueryInstrumentation;

    // THEN PART 1
    // query cannot be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(0);
    EXPECT_CALL( *m_postgres_mock, InstrAggNode( m_rootQuery->totaltime, m_subQuery->totaltime ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_subQuery.get());
  }

  BOOST_AUTO_TEST_CASE( subquery_tuples_gt_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );

    m_rootQuery->totaltime->tuplecount = tuplesLimit + 10;
    Instrumentation subQueryInstrumentation;
    m_subQuery->totaltime = &subQueryInstrumentation;

    // THEN PART 1
    // query must be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(1);
    EXPECT_CALL( *m_postgres_mock, InstrAggNode( m_rootQuery->totaltime, m_subQuery->totaltime ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_subQuery.get());
  }

  BOOST_AUTO_TEST_CASE( handler_error_handling_from_finish ) {
    using namespace ::testing;
    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );

    // we pretend an error by jumping to the beginning of a handler's body
    ON_CALL( *m_postgres_mock, executorFinishHook( _ ) ).WillByDefault(
      []{ MAKE_POSTGRES_ERROR;}
    );

    // WHEN
    EXPECT_PG_ERROR( ExecutorFinish_hook( m_rootQuery.get() ) );

    // THEN
    // a postgres error shall reset handler state
    BOOST_ASSERT( !m_unitUnderTest->isRootQueryPending());
  }

  BOOST_AUTO_TEST_CASE( handler_error_handling_from_end ) {
    using namespace ::testing;
    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( []{ return tuplesLimit; } );
    ExecutorFinish_hook( m_rootQuery.get() );

    // we pretend an error by jumping to the beginning of a handler's body
    ON_CALL( *m_postgres_mock, executorEndHook( _ ) ).WillByDefault(
      []{ MAKE_POSTGRES_ERROR;}
    );

    // WHEN
    EXPECT_PG_ERROR( ExecutorEnd_hook( m_rootQuery.get() ) );

    // THEN
    // a postgres error shall reset handler state
    BOOST_ASSERT( !m_unitUnderTest->isRootQueryPending());
  }


BOOST_AUTO_TEST_SUITE_END()
