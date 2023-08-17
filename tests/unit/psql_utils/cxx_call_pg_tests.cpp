#include <boost/test/unit_test.hpp>

#include "mock/gmock_fixture.hpp"

#include <psql_utils/error_reporting.h>

BOOST_FIXTURE_TEST_SUITE( cxx_call_pg_tests, GmockFixture )

BOOST_AUTO_TEST_CASE( cxx_call_pg_returns_a_value_if_no_error )
{
  BOOST_CHECK_EQUAL(
    PsqlTools::PsqlUtils::cxx_call_pg([]() -> int { return 42; }),
    42
  );
}

BOOST_AUTO_TEST_CASE( cxx_call_pg_turns_pg_error_into_cpp_exception )
{
  BOOST_CHECK_THROW(
    PsqlTools::PsqlUtils::cxx_call_pg([]() -> int {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ) ) );
    }),
    PsqlTools::PsqlUtils::PgError
  );
}

BOOST_AUTO_TEST_CASE( cxx_call_pg_in_call_cxx_turns_pg_error_back_into_pg_error )
{
  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::call_cxx([](){
    PsqlTools::PsqlUtils::cxx_call_pg([]() -> int {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ) ) );
    });
  }));
}

BOOST_AUTO_TEST_SUITE_END()