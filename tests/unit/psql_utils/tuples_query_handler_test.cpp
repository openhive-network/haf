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
    moveToRunRootQuery( tuplesLimit, timeout );

    m_rootQuery->totaltime->tuplecount = tuplesLimit - 10;

    // THEN PART 1
    // query cannot be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(0);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( tuples_eq_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( tuplesLimit, timeout );

    m_rootQuery->totaltime->tuplecount = tuplesLimit;

    // THEN PART 1
    // query cannot be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(0);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( tuples_gt_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( tuplesLimit, timeout );

    m_rootQuery->totaltime->tuplecount = tuplesLimit + 10;

    // THEN PART 1
    // query must be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    // THEN PART 2
    BOOST_ASSERT( !PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( subquery_tuples_less_than_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( tuplesLimit, timeout );

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

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( subquery_tuples_eq_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( tuplesLimit, timeout );

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

    // THEN PART 2
    BOOST_ASSERT( PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }

  BOOST_AUTO_TEST_CASE( subquery_tuples_gt_limit ) {
    using namespace testing;

    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery( tuplesLimit, timeout );

    m_rootQuery->totaltime->tuplecount = tuplesLimit + 10;
    Instrumentation subQueryInstrumentation;
    m_subQuery->totaltime = &subQueryInstrumentation;

    // THEN PART 1
    // query cannot be broken
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(1);
    EXPECT_CALL( *m_postgres_mock, InstrAggNode( m_rootQuery->totaltime, m_subQuery->totaltime ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_subQuery.get());

    // THEN PART 2
    BOOST_ASSERT( !PsqlTools::PsqlUtils::TimeoutQueryHandler::isRootQueryPending() );
  }


BOOST_AUTO_TEST_SUITE_END()