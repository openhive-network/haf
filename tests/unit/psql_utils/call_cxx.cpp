#include <boost/test/unit_test.hpp>

#include "mock/gmock_fixture.hpp"

#include <psql_utils/error_reporting.h>

BOOST_FIXTURE_TEST_SUITE( call_cxx_tests, GmockFixture )

BOOST_AUTO_TEST_CASE( foo )
{
  int res = 0;
  PsqlTools::PsqlUtils::call_cxx([&res](){
    res = 7;
  });
  BOOST_CHECK(res == 7);
}

BOOST_AUTO_TEST_SUITE_END()

