#include <boost/test/unit_test.hpp>

#include "mock/gmock_fixture.hpp"

#include <psql_utils/error_reporting.h>

BOOST_FIXTURE_TEST_SUITE( pg_call_cxx_tests, GmockFixture )

BOOST_AUTO_TEST_CASE( pg_call_cxx_allows_to_set_value_if_no_error )
{
  int res = 0;
  PsqlTools::PsqlUtils::pg_call_cxx([&res](){
    res = 7;
  });
  BOOST_CHECK(res == 7);
}

BOOST_AUTO_TEST_CASE( std_runtime_error_is_converted_to_postgres_error )
{
  int res = 0;
  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::pg_call_cxx([&res](){
    throw std::runtime_error("some error");
  }));
  BOOST_CHECK(res == 0);
}

BOOST_AUTO_TEST_CASE( std_logic_error_is_converted_to_postgres_error )
{
  int res = 0;
  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::pg_call_cxx([&res](){
    throw std::logic_error("some error");
  }));
  BOOST_CHECK(res == 0);
}

BOOST_AUTO_TEST_CASE( fc_exception_is_converted_to_postgres_error )
{
  int res = 0;
  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::pg_call_cxx([&res](){
    FC_THROW_EXCEPTION( fc::assert_exception, "test exception" );
  }));
  BOOST_CHECK(res == 0);
}

BOOST_AUTO_TEST_CASE( exception_sets_the_passed_errcode )
{
  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::pg_call_cxx([](){
    throw std::runtime_error("some error");
  }, ERRCODE_INVALID_TEXT_REPRESENTATION));
  BOOST_CHECK(geterrcode() == ERRCODE_INVALID_TEXT_REPRESENTATION);

  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::pg_call_cxx([](){
    throw std::runtime_error("some error");
  }, ERRCODE_INVALID_BINARY_REPRESENTATION));
  BOOST_CHECK(geterrcode() == ERRCODE_INVALID_BINARY_REPRESENTATION);
}

BOOST_AUTO_TEST_CASE( postgres_error_is_caught )
{
  int res = 0;
  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::pg_call_cxx([&res](){
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ) ) );
  }));
  BOOST_CHECK(res == 0);
}

BOOST_AUTO_TEST_CASE( postgres_warning_is_not_an_error )
{
  int res = 0;
  PsqlTools::PsqlUtils::pg_call_cxx([&res](){
    ereport( WARNING, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "%s", "warning") ) );
    res = 8;
  });
  BOOST_CHECK(res == 8);
}

BOOST_AUTO_TEST_CASE( pg_call_cxx_resets_PG_exception_stack_on_exit )
{
  BOOST_REQUIRE_EQUAL(PG_exception_stack, nullptr);
  EXPECT_PG_ERROR(PsqlTools::PsqlUtils::pg_call_cxx([](){
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "%s", "error") ) );
  }));
  BOOST_REQUIRE_EQUAL(PG_exception_stack, nullptr);
  PsqlTools::PsqlUtils::pg_call_cxx([](){
    ereport( NOTICE, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "%s", "notice") ) );
  });
  BOOST_REQUIRE_EQUAL(PG_exception_stack, nullptr);
}

BOOST_AUTO_TEST_SUITE_END()

