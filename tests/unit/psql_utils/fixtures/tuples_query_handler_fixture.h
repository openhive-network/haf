#pragma once

#include "mock/gmock_fixture.hpp"
#include "timeout_query_handler_fixture.h"

#include "psql_utils/query_handler/tuples_query_handler.h"

#include "mock/postgres_mock.hpp"

#include <chrono>

namespace Fixtures {

  struct TuplesQueryHandlerFixture : public GmockFixture{
    TuplesQueryHandlerFixture();

    ~TuplesQueryHandlerFixture();

    void moveToRunRootQuery( PsqlTools::PsqlUtils::TuplesQueryHandler::TuplesLimitGetter _limit );

    std::unique_ptr<QueryDesc> m_rootQuery;
    std::unique_ptr<QueryDesc> m_subQuery;
    Instrumentation m_instrumentation{};

    std::shared_ptr< PsqlTools::PsqlUtils::TuplesQueryHandler > m_unitUnderTest;
  };



} // namespace Fixtures
