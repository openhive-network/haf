#include <boost/test/unit_test.hpp>

#include "mock/pq_mock.hpp"
#include "mock/postgres_mock.hpp"

#include "pq_utils/db_client.hpp"
#include "include/exceptions.hpp"

using ::testing::Return;

BOOST_AUTO_TEST_SUITE( db_client )

BOOST_AUTO_TEST_CASE( positivie_client_connect )
{
  auto pq_mock = PqMock::create_and_get();

  static constexpr auto db_name = "test_db";
  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );

  // 1. connect to database
  EXPECT_CALL( *pq_mock, PQconnectdb( ::testing::StrEq( "dbname=test_db" ) ) )
          .Times(1)
          .WillOnce( Return( connection_ptr ) )
  ;

  // 2. check status
  EXPECT_CALL( *pq_mock, PQstatus( connection_ptr ) )
          .WillOnce( Return( CONNECTION_OK ) ) //for c_tor
          .WillOnce( Return( CONNECTION_OK ) ) //for positivie case of isConnected
          .WillRepeatedly( Return( CONNECTION_BAD ) ) // //for negative case of isConnected
  ;

  // 3. disconnect when the client is destroyed
  EXPECT_CALL( *pq_mock, PQfinish( connection_ptr ) )
          .Times(1)
  ;

  PsqlTools::PostgresPQ::DbClient object_uder_test( db_name );
  BOOST_CHECK( object_uder_test.isConnected() );
  BOOST_CHECK( !object_uder_test.isConnected() );
}

BOOST_AUTO_TEST_CASE( negative_client_cannot_connect )
{
  auto pq_mock = PqMock::create_and_get_nice();

  static constexpr auto db_name = "test_db";
  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );

  // 1. connect and return valid connection
  EXPECT_CALL( *pq_mock, PQconnectdb( ::testing::StrEq( "dbname=test_db" ) ) )
          .Times(1)
          .WillOnce( Return( connection_ptr ) )
          ;
  // 2. return wrong connection status
  EXPECT_CALL( *pq_mock, PQstatus( connection_ptr ) )
          .WillRepeatedly( Return( CONNECTION_BAD ) )
          ;

  BOOST_CHECK_THROW(
      PsqlTools::PostgresPQ::DbClient object_uder_test( db_name )
    , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_CASE( negative_client_cannot_connect_because_out_of_memory )
{
  auto pq_mock = PqMock::create_and_get_nice();

  static constexpr auto db_name = "test_db";

  // 1. connect and return nullptr as the connection
  EXPECT_CALL( *pq_mock, PQconnectdb( ::testing::StrEq( "dbname=test_db" ) ) )
          .Times(1)
          .WillOnce( Return( nullptr ) )
          ;

  BOOST_CHECK_THROW(
    PsqlTools::PostgresPQ::DbClient object_uder_test( db_name ),
    PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_SUITE_END()