#include "fixtures/tuples_query_handler_fixture.h"

namespace Fixtures {

  TuplesStatisticsQueryHandlerFixture::TuplesStatisticsQueryHandlerFixture() {
    ExecutorStart_hook = executorStartHook;
    ExecutorRun_hook = executorRunHook;
    ExecutorFinish_hook = executorFinishHook;
    ExecutorEnd_hook = executorEndHook;

    QueryCancelPending = false;

    m_rootQuery = std::make_unique<QueryDesc>();
    m_rootQuery->operation = CMD_SELECT;
    m_subQuery = std::make_unique<QueryDesc>();
  }

  TuplesStatisticsQueryHandlerFixture::~TuplesStatisticsQueryHandlerFixture() {
    ExecutorStart_hook = nullptr;
    ExecutorRun_hook = nullptr;
    ExecutorFinish_hook = nullptr;
    ExecutorEnd_hook = nullptr;
  }

  void TuplesStatisticsQueryHandlerFixture::moveToRunRootQuery() {
    using namespace testing;

    m_rootQuery->totaltime = nullptr;
    // assumption that CMD_SELECT is only supported operation
    if ( m_rootQuery->operation == CMD_SELECT ) {
      EXPECT_CALL( *m_postgres_mock, InstrAlloc( _, _, _ )).WillOnce( Return( &m_instrumentation ));
    }

    if (ExecutorStart_hook) {
      EXPECT_CALL( *m_postgres_mock, executorStartHook( m_rootQuery.get(), _ )).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( m_rootQuery.get(), _ )).Times( 1 );
    }

    if (ExecutorRun_hook) {
      EXPECT_CALL( *m_postgres_mock, executorRunHook( _, _, _, _ ) ).Times( AtLeast(1) );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorRun( _, _, _, _ ) ).Times( 1 );
    }

    if (ExecutorFinish_hook) {
      EXPECT_CALL( *m_postgres_mock, executorFinishHook( _ ) ).Times( AtLeast(1) );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorFinish( _ ) ).Times( 1 );
    }

    if ( !m_unitUnderTest ) {
      m_unitUnderTest = std::make_shared<ClassUnderTest>();
    }

    ExecutorStart_hook( m_rootQuery.get(), 0 );
    ExecutorRun_hook( m_rootQuery.get(), BackwardScanDirection, 0, true );
  }



} // namespace Fixtures
