#include <boost/test/unit_test.hpp>

#include "mock/gmock_fixture.hpp"

#include "psql_utils/custom_configuration.h"

#include "mock/postgres_mock.hpp"

using namespace PsqlTools::PsqlUtils;

BOOST_FIXTURE_TEST_SUITE( custom_configuration, GmockFixture )

  BOOST_AUTO_TEST_CASE( string_option_create ) {
    using namespace ::testing;

    CustomConfiguration objectUnderTest( "root" );

    EXPECT_CALL( *m_postgres_mock, DefineCustomStringVariable(
      StrEq("root.option"), StrEq("short"), StrEq("long"), _, StrEq("default"), GucContext::PGC_SUSET, 0, nullptr, nullptr, nullptr  )
    ).Times(1);

    objectUnderTest.addStringOption( "option", "short", "long", "default" );

    auto option = objectUnderTest.getOption( "option" );
    BOOST_CHECK( std::holds_alternative< std::string >( option ) );
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

  BOOST_AUTO_TEST_CASE( int_option_create ) {
    using namespace ::testing;

    auto const defaultValue = 1313;

    CustomConfiguration objectUnderTest( "root" );

    EXPECT_CALL( *m_postgres_mock, DefineCustomIntVariable(
        StrEq("root.option")
      , StrEq("short")
      , StrEq("long")
      , _
      , defaultValue
      , std::numeric_limits< int32_t >::min()
      , std::numeric_limits< int32_t >::max()
      , GucContext::PGC_SUSET, _, _, _, _  )
    ).Times(1);

    objectUnderTest.addIntOption( "option", "short", "long", defaultValue );

    auto option = objectUnderTest.getOption( "option" );
    BOOST_CHECK( std::holds_alternative< int >( option ) );
  }

  BOOST_AUTO_TEST_CASE( distinguish_between_options ) {
    using namespace ::testing;

    auto const defaultValue = 1313;

    CustomConfiguration objectUnderTest( "root" );

    EXPECT_CALL( *m_postgres_mock, DefineCustomStringVariable(
      StrEq("root.option_string"), StrEq("short"), StrEq("long"), _, StrEq("default"), GucContext::PGC_SUSET, 0, nullptr, nullptr, nullptr  )
    ).Times(1);

    objectUnderTest.addStringOption( "option_string", "short", "long", "default" );

    EXPECT_CALL( *m_postgres_mock, DefineCustomIntVariable(
        StrEq("root.option_int")
      , StrEq("short")
      , StrEq("long")
      , _
      , defaultValue
      , std::numeric_limits< int32_t >::min()
      , std::numeric_limits< int32_t >::max()
      , GucContext::PGC_SUSET, _, _, _, _  )
    ).Times(1);

    objectUnderTest.addIntOption( "option_int", "short", "long", defaultValue );

    auto optionInt = objectUnderTest.getOption( "option_int" );
    auto optionString = objectUnderTest.getOption( "option_string" );
    BOOST_CHECK( std::holds_alternative< int >( optionInt ) );
    BOOST_CHECK( std::holds_alternative< std::string >( optionString ) );
  }

  BOOST_AUTO_TEST_CASE( positivie_int_option_create ) {
    using namespace ::testing;

    auto const defaultValue = 1313u;

    CustomConfiguration objectUnderTest( "root" );

    EXPECT_CALL( *m_postgres_mock, DefineCustomIntVariable(
      StrEq("root.option")
      , StrEq("short")
      , StrEq("long")
      , _
      , static_cast< int >( defaultValue )
      , 0
      , std::numeric_limits< int32_t >::max()
      , GucContext::PGC_SUSET, _, _, _, _  )
    ).Times(1);

    objectUnderTest.addPositiveIntOption( "option", "short", "long", defaultValue );

    auto option = objectUnderTest.getOption( "option" );
    BOOST_CHECK( std::holds_alternative< uint32_t >( option ) );
  }

BOOST_AUTO_TEST_SUITE_END()
