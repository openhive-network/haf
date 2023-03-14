#include <boost/test/unit_test.hpp>

#include "include/psql_utils/custom_configuration.h"

#include "mock/postgres_mock.hpp"

using namespace PsqlTools::PsqlUtils;

struct custom_configuration_fixture {
  custom_configuration_fixture() {
    m_postgres_mock = PostgresMock::create_and_get();
  }

  ~custom_configuration_fixture() {
  }

  std::shared_ptr<PostgresMock> m_postgres_mock;
};

BOOST_FIXTURE_TEST_SUITE( custom_configuration, custom_configuration_fixture )

  BOOST_AUTO_TEST_CASE( string_option_create ) {
    using namespace ::testing;

    CustomConfiguration objectUnderTest( "root" );

    /*EXPECT_CALL( *m_postgres_mock, DefineCustomStringVariable(
      Eq("root.option"), Eq("short"), Eq("long"), _, Eq("default"), GucContext::PGC_SIGHUP, 0, nullptr, nullptr, nullptr  )
    ).Times(1);*/

    EXPECT_CALL( *m_postgres_mock, DefineCustomStringVariable(
      StrEq("root.option"), StrEq("short"), StrEq("long"), _, StrEq("default"), GucContext::PGC_SIGHUP, 0, nullptr, nullptr, nullptr  )
    ).Times(1);

    objectUnderTest.addStringOption( "option", "short", "long", "default" );
  }

  BOOST_AUTO_TEST_CASE( get_any_option_as_string ) {
    using namespace ::testing;

    CustomConfiguration objectUnderTest( "root" );

    EXPECT_CALL( *m_postgres_mock, GetConfigOption(
      StrEq("root.option"), false, false  )
    ).Times(1)
    .WillOnce( Return( const_cast<char*>("value") ) )
    ;

    auto result = objectUnderTest.getOptionAsString( "option" );

    BOOST_REQUIRE_EQUAL( result, "value" );
  }

  BOOST_AUTO_TEST_CASE( get_any_option_as_string_no_option ) {
    using namespace ::testing;

    CustomConfiguration objectUnderTest( "root" );

    EXPECT_CALL( *m_postgres_mock, GetConfigOption(
      StrEq("root.option"), false, false  ))
    .Times(1)
    .WillOnce( Return(nullptr) )
    ;

    BOOST_CHECK_THROW( objectUnderTest.getOptionAsString( "option" ), std::runtime_error );
  }

BOOST_AUTO_TEST_SUITE_END()
