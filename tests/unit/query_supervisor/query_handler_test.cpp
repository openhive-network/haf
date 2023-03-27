#include <boost/test/unit_test.hpp>

#include "psql_utils/postgres_includes.hpp"

#include "query_handler.h"

using namespace PsqlTools::QuerySupervisor;

struct start_query_handler_fixture
{
  start_query_handler_fixture() { ExecutorStart_hook = nullptr; }
  ~start_query_handler_fixture() { ExecutorStart_hook = nullptr; }
};

BOOST_FIXTURE_TEST_SUITE( start_query_handler, start_query_handler_fixture )

BOOST_AUTO_TEST_CASE( create_handler ) {
  StartQueryHandler unitUnderTest;

  BOOST_REQUIRE_EQUAL(ExecutorStart_hook, nullptr);
}

BOOST_AUTO_TEST_CASE( delete_handler ) {
  {
    StartQueryHandler unitUnderTest;
  }

  BOOST_REQUIRE_EQUAL(ExecutorStart_hook, nullptr);
}

BOOST_AUTO_TEST_SUITE_END()