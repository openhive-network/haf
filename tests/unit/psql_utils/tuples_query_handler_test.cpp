#include <boost/test/unit_test.hpp>
#include "fixtures/tuples_query_handler_fixture.h"

#include "psql_utils/query_handler/tuples_statistics_query_handler.hpp"

#include <chrono>

using namespace std::chrono_literals;

BOOST_FIXTURE_TEST_SUITE( tuples_query_handler, Fixtures::TuplesStatisticsQueryHandlerFixture )

  BOOST_AUTO_TEST_CASE( select ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuples = 100;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_SELECT;
    m_rootQuery->totaltime->tuplecount = tuples;

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), tuples );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuples );
  }

  BOOST_AUTO_TEST_CASE( update ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuples = 100;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_UPDATE;
    m_rootQuery->totaltime->tuplecount = tuples;

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), 0 );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), tuples );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuples );
  }

  BOOST_AUTO_TEST_CASE( insert ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuples = 100;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_INSERT;
    m_rootQuery->totaltime->tuplecount = tuples;

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), 0 );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0 );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), tuples );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuples );
  }

  BOOST_AUTO_TEST_CASE( delete_cmd ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuples = 100;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_DELETE;
    m_rootQuery->totaltime->tuplecount = tuples;

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), tuples );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuples );
  }

  BOOST_AUTO_TEST_CASE( other ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuples = 100;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_UNKNOWN;
    m_rootQuery->totaltime->tuplecount = tuples;

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), tuples );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuples );
  }

  BOOST_AUTO_TEST_CASE( subquery_instrumentation ) {
    using namespace testing;

    // GIVEN
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_UPDATE;

    Instrumentation subQueryInstrumentation;
    m_subQuery->operation = CMD_SELECT;

    // THEN
    EXPECT_CALL( *m_postgres_mock, InstrAlloc( 1, INSTRUMENT_ALL, true ) )
      .Times(1)
      .WillOnce( Return( &subQueryInstrumentation ) )
      ;

    // WHEN
    ExecutorRun_hook(m_subQuery.get(), BackwardScanDirection, 0, true );
    ExecutorFinish_hook(m_subQuery.get());
  }

  BOOST_AUTO_TEST_CASE( subquery_update_select ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuplesUpdate = 100;
    const auto tuplesSelect = 200;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_UPDATE;
    m_rootQuery->totaltime->tuplecount = tuplesUpdate;

    Instrumentation subQueryInstrumentation;
    subQueryInstrumentation.tuplecount = tuplesSelect;
    m_subQuery->operation = CMD_SELECT;

    // THEN PART 1
    //
    EXPECT_CALL( *m_postgres_mock, InstrAlloc( 1, INSTRUMENT_ALL, true ) )
      .Times(1)
      .WillOnce( Return( &subQueryInstrumentation ) )
    ;

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorRun_hook(m_subQuery.get(), BackwardScanDirection, 0, true );
    ExecutorFinish_hook(m_subQuery.get());
    ExecutorFinish_hook(m_rootQuery.get());

    // THEN
    //THEN
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), tuplesSelect );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), tuplesUpdate );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuplesSelect + tuplesUpdate );
  }

  BOOST_AUTO_TEST_CASE( break_query ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuplesSelectRoot = ClassUnderTest::LIMIT;
    const auto tuplesSelectSubQuery = ClassUnderTest::LIMIT/2;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_SELECT;
    m_rootQuery->totaltime->tuplecount = tuplesSelectRoot;

    Instrumentation subQueryInstrumentation;
    subQueryInstrumentation.tuplecount = tuplesSelectSubQuery;
    m_subQuery->operation = CMD_SELECT;

    // THEN PART 1
    //
    EXPECT_CALL( *m_postgres_mock, InstrAlloc( 1, INSTRUMENT_ALL, true ) )
      .Times(1)
      .WillOnce( Return( &subQueryInstrumentation ) )
      ;
    EXPECT_CALL( *m_postgres_mock, StatementCancelHandler( _ ) ).Times(1);

    // WHEN
    // pretend that PostgreSQL calls our finish handler
    ExecutorRun_hook(m_subQuery.get(), BackwardScanDirection, 0, true );
    ExecutorFinish_hook(m_subQuery.get());
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), tuplesSelectRoot + tuplesSelectSubQuery );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuplesSelectRoot + tuplesSelectSubQuery );
  }

  BOOST_AUTO_TEST_CASE( sequence_of_root_queries ) {
    using namespace testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuplesSelectRoot = ClassUnderTest::LIMIT/2;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_SELECT;
    m_instrumentation.tuplecount = tuplesSelectRoot;

    // WHEN 1 - first execution of a query
    // pretend that PostgreSQL calls our finish handler
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN 1
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), tuplesSelectRoot );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuplesSelectRoot );

    // WHEN 2 - second execution of a query, previous statistics need to be reset and count from scratch
    // pretend that PostgreSQL calls our finish handler

    moveToRunRootQuery();
    ExecutorFinish_hook(m_rootQuery.get());

    //THEN 1
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), tuplesSelectRoot );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );

    BOOST_CHECK_EQUAL( m_unitUnderTest->numberOfAllTuples(), tuplesSelectRoot );
  }

  BOOST_AUTO_TEST_CASE( handler_error_handling_from_finish ) {
    using namespace ::testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;
    // GIVEN
    const auto tuplesLimit = 100;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_SELECT;
    m_instrumentation.tuplecount = tuplesLimit;

    // we pretend an error by jumping to the beginning of a handler's body
    ON_CALL( *m_postgres_mock, executorFinishHook( _ ) ).WillByDefault(
      []{ ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ) ) );}
    );

    // WHEN
    EXPECT_PG_ERROR( ExecutorFinish_hook( m_rootQuery.get() ) );

    // THEN
    // a postgres error shall reset handler state
    BOOST_ASSERT( !m_unitUnderTest->isRootQueryPending() );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );
  }

  BOOST_AUTO_TEST_CASE( handler_error_handling_from_end ) {
    using namespace ::testing;
    using PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler;
    using SqlCommand = TuplesStatisticsQueryHandler::SqlCommand;

    // GIVEN
    const auto tuplesLimit = 50;
    std::chrono::milliseconds timeout = 1s;
    moveToRunRootQuery();

    m_rootQuery->operation = CMD_SELECT;
    m_instrumentation.tuplecount = tuplesLimit;

    ExecutorFinish_hook( m_rootQuery.get() );

    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), 50 );

    // we pretend an error by jumping to the beginning of a handler's body
    ON_CALL( *m_postgres_mock, executorEndHook( _ ) ).WillByDefault(
      []{ ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ) ) );}
    );

    // WHEN
    EXPECT_PG_ERROR( ExecutorEnd_hook( m_rootQuery.get() ) );

    // THEN
    // a postgres error shall reset handler state
    BOOST_ASSERT( !m_unitUnderTest->isRootQueryPending() );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::SELECT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::UPDATE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::INSERT ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::DELETE ), 0u );
    BOOST_CHECK_EQUAL( m_unitUnderTest->getStatistics().at( SqlCommand::OTHER ), 0u );
  }

BOOST_AUTO_TEST_SUITE_END()
