#pragma once

#include "timeout_query_handler_fixture.h"

#include "psql_utils/query_handler/tuples_query_handler.h"

#include "mock/postgres_mock.hpp"

#include <chrono>

namespace Fixtures {

  struct TuplesQueryHandlerFixture : public TimeoutQueryHandlerFixture {
    TuplesQueryHandlerFixture();

    ~TuplesQueryHandlerFixture();

    void moveToRunRootQuery( int _limit, std::chrono::milliseconds _timeout );

    Instrumentation m_instrumentation{};
  };



} // namespace Fixtures
