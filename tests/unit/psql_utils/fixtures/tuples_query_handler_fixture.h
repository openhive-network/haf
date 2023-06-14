#pragma once

#include "mock/gmock_fixture.hpp"
#include "timeout_query_handler_fixture.h"

#include "psql_utils/query_handler/tuples_statistics_query_handler.hpp"

#include "mock/postgres_mock.hpp"

#include <chrono>

namespace Fixtures {

  struct TuplesStatisticsQueryHandlerFixture : public GmockFixture{
    TuplesStatisticsQueryHandlerFixture();

    ~TuplesStatisticsQueryHandlerFixture();

    void moveToRunRootQuery();

    std::unique_ptr<QueryDesc> m_rootQuery;
    std::unique_ptr<QueryDesc> m_subQuery;
    Instrumentation m_instrumentation{};

    class ClassUnderTest : public PsqlTools::PsqlUtils::TuplesStatisticsQueryHandler
    {
      public:
        static constexpr auto LIMIT = 10000u;
        bool breakQuery() const override {
          return numberOfAllTuples() > LIMIT;
        }
    };
    std::shared_ptr< ClassUnderTest > m_unitUnderTest;
  };



} // namespace Fixtures
