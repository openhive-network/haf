#include "fixtures/timeout_query_handler_fixture.h"

namespace Fixtures {

  TimeoutQueryHandlerFixture::TimeoutQueryHandlerFixture() {
    ExecutorStart_hook = executorStartHook;
    ExecutorRun_hook = executorRunHook;
    ExecutorFinish_hook = executorFinishHook;
    ExecutorEnd_hook = executorEndHook;

    QueryCancelPending = false;

    m_postgres_mock = PostgresMock::create_and_get();
    m_rootQuery = std::make_unique<QueryDesc>();
    m_subQuery = std::make_unique<QueryDesc>();
  }

  TimeoutQueryHandlerFixture::~TimeoutQueryHandlerFixture() {
    ExecutorStart_hook = nullptr;
    ExecutorRun_hook = nullptr;
    ExecutorFinish_hook = nullptr;
    ExecutorEnd_hook = nullptr;

    if (PsqlTools::PsqlUtils::TimeoutQueryHandler::isInitialized()) {
      EXPECT_CALL( *m_postgres_mock, disable_timeout( ::testing::_, ::testing::_ )).Times( 1 );
      PsqlTools::PsqlUtils::QueryHandler::deinitialize<PsqlTools::PsqlUtils::TimeoutQueryHandler>();
    }
  }



} // namespace Fixtures
