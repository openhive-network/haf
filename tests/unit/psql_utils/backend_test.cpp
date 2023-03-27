#include <boost/test/unit_test.hpp>
#include "mock/postgres_mock.hpp"

#include "include/psql_utils/backend.h"

using namespace PsqlTools;
using ::testing::Return;
using ::testing::InSequence;
using ::testing::StrEq;
using ::testing::_;

BOOST_AUTO_TEST_SUITE( backend )

  BOOST_AUTO_TEST_CASE( userOid )
  {
    auto postgres_mock = PostgresMock::create_and_get();
    const Oid expectedUserId = 1313;

    PsqlUtils::Backend unitUnderTest;

    EXPECT_CALL( *postgres_mock, GetSessionUserId() )
      .Times( 1 )
      .WillOnce( ::Return( expectedUserId ) )
      ;

    const auto result = unitUnderTest.userOid();

    BOOST_REQUIRE_EQUAL( result, expectedUserId );
  }

  /** cannot test Backed::userName() because types name conflict between
  * regex used by gmock ( which uses /usr/include/regex.h ) and postgres regex incorporated into its code
  * BOOST_AUTO_TEST_CASE( username )
  * {
  *   auto* expectedUserName = "alice";
  *   MyProcPort->user_name = expectedUserName;
  *   PsqlUtils::Backend unitUnderTest;
  *   const auto result = unitUnderTest.userName();
  *   BOOST_REQUIRE( strcmp( result.c_str(), expectedUserName ) );
  * }
  */


BOOST_AUTO_TEST_SUITE_END()