#include "fixtures/timeout_query_handler_fixture.h"

namespace Fixtures {

  TimeoutQueryHandlerFixture::TimeoutQueryHandlerFixture() {
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

  TimeoutQueryHandlerFixture::~TimeoutQueryHandlerFixture() {
    ExecutorStart_hook = nullptr;
    ExecutorRun_hook = nullptr;
    ExecutorFinish_hook = nullptr;
    ExecutorEnd_hook = nullptr;

    if (m_unitUnderTest) {
      EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ )).Times( 1 );
      m_unitUnderTest.reset();
    }
  }



} // namespace Fixtures
