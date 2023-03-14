#include "fixtures/tuples_query_handler_fixture.h"

namespace Fixtures {

  TuplesQueryHandlerFixture::TuplesQueryHandlerFixture() {
  }

  TuplesQueryHandlerFixture::~TuplesQueryHandlerFixture() {
  }

  void TuplesQueryHandlerFixture::moveToRunRootQuery(int _limit, std::chrono::milliseconds _timeout) {
    using namespace testing;

    EXPECT_CALL( *m_postgres_mock, InstrAlloc( _, _, _ ) ).WillOnce( Return(&m_instrumentation) );

    if (ExecutorRun_hook) {
      EXPECT_CALL( *m_postgres_mock, executorRunHook( _, _, _, _ ) ).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorRun( _, _, _, _ ) ).Times( 1 );
    }

    if (ExecutorFinish_hook) {
      EXPECT_CALL( *m_postgres_mock, executorFinishHook( _ ) ).Times( 1 );
    } else {
      EXPECT_CALL( *m_postgres_mock, standard_ExecutorFinish( _ ) ).Times( 1 );
    }

    moveToPendingRootQuery< PsqlTools::PsqlUtils::TuplesQueryHandler >( _limit, _timeout );

    ExecutorRun_hook( m_rootQuery.get(), BackwardScanDirection, 0, true );
  }



} // namespace Fixtures
