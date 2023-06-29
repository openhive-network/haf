#include "fixtures/tuples_query_handler_fixture.h"

namespace Fixtures {

  TuplesQueryHandlerFixture::TuplesQueryHandlerFixture() {
    ExecutorStart_hook = executorStartHook;
    ExecutorRun_hook = executorRunHook;
    ExecutorFinish_hook = executorFinishHook;
    ExecutorEnd_hook = executorEndHook;

    QueryCancelPending = false;

    m_rootQuery = std::make_unique<QueryDesc>();
    m_rootDestReceiver = std::make_unique<DestReceiver>();
    m_rootQuery->dest = m_rootDestReceiver.get();
    m_rootQuery->dest->mydest = DestNone;

    m_subQuery = std::make_unique<QueryDesc>();
    m_subDestReceiver = std::make_unique<DestReceiver>();
    m_subQuery->dest = m_subDestReceiver.get();
    m_subQuery->dest->mydest = DestSPI;
  }

  TuplesQueryHandlerFixture::~TuplesQueryHandlerFixture() {
    ExecutorStart_hook = nullptr;
    ExecutorRun_hook = nullptr;
    ExecutorFinish_hook = nullptr;
    ExecutorEnd_hook = nullptr;
  }

  void TuplesQueryHandlerFixture::moveToRunRootQuery( PsqlTools::PsqlUtils::TuplesQueryHandler::TuplesLimitGetter _limit ) {
    using namespace testing;

    EXPECT_CALL( *m_postgres_mock, InstrAlloc( _, _, _ ) ).WillOnce( Return(&m_instrumentation) );

    if (ExecutorStart_hook) {
      EXPECT_CALL( *m_postgres_mock, executorStartHook( m_rootQuery.get(), _ )).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorStart( m_rootQuery.get(), _ )).Times( 1 );
    }

    if (ExecutorRun_hook) {
      EXPECT_CALL( *m_postgres_mock, executorRunHook( _, _, _, _ ) ).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorRun( _, _, _, _ ) ).Times( 1 );
    }

    if (ExecutorFinish_hook) {
      EXPECT_CALL( *m_postgres_mock, executorFinishHook( _ ) ).Times( AnyNumber() );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorFinish( _ ) ).Times( 1 );
    }

    m_unitUnderTest = std::make_shared< PsqlTools::PsqlUtils::TuplesQueryHandler >( _limit );

    ExecutorStart_hook( m_rootQuery.get(), 0 );
    ExecutorRun_hook( m_rootQuery.get(), BackwardScanDirection, 0, true );
  }



} // namespace Fixtures
