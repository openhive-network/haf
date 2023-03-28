#include <boost/test/unit_test.hpp>

#include "mock/pq_mock.hpp"
#include "mock/gmock_fixture.hpp"

#include "pq_utils/transaction.hpp"
#include "include/exceptions.hpp"

using ::testing::Return;

BOOST_FIXTURE_TEST_SUITE( pq_transaction, GmockFixture )

BOOST_AUTO_TEST_CASE( positivie_client_connect )
{
  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );
  std::shared_ptr< pg_conn > connection( connection_ptr, [](pg_conn*){} );
  PGresult* result_ptr( reinterpret_cast< PGresult* >( 0xAAAAFFFFFFFFFFFF ) );

  // 1. execute BEGIN TRANSACTION
  EXPECT_CALL( *m_pq_mock, PQexec( connection_ptr, ::testing::StrEq( "BEGIN TRANSACTION" ) ) )
          .Times(1)
          .WillOnce( Return( result_ptr ) )
  ;

  // 2. check status
  EXPECT_CALL( *m_pq_mock, PQresultStatus( result_ptr ) )
          .Times(2)
          .WillOnce( Return( PGRES_COMMAND_OK ) ) // for c_tor
          .WillOnce( Return( PGRES_COMMAND_OK ) ) // for d_tor
  ;

  // 3. execute COMMIT
  EXPECT_CALL( *m_pq_mock, PQexec( connection_ptr, ::testing::StrEq( "COMMIT" ) ) )
          .Times(1)
          .WillOnce( Return( result_ptr ) )
  ;

  BOOST_CHECK_NO_THROW( PsqlTools::PostgresPQ::Transaction object_uder_test( connection ) );
}

BOOST_AUTO_TEST_CASE( negative_client_cannot_start_transaction )
{
  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );
  std::shared_ptr< pg_conn > connection( connection_ptr, [](pg_conn*){} );
  PGresult* result_ptr( reinterpret_cast< PGresult* >( 0xAAAAFFFFFFFFFFFF ) );

  // 1. execute BEGIN TRANSACTION
  EXPECT_CALL( *m_pq_mock, PQexec( connection_ptr, ::testing::StrEq( "BEGIN TRANSACTION" ) ) )
          .Times(1)
          .WillOnce( Return( result_ptr ) )
          ;

  // 2. check status
  EXPECT_CALL( *m_pq_mock, PQresultStatus( result_ptr ) )
          .Times(1)
          .WillOnce( Return( PGRES_FATAL_ERROR ) ) // for c_tor
          ;

  BOOST_CHECK_THROW(
      PsqlTools::PostgresPQ::Transaction object_uder_test( connection )
    , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_CASE( negative_client_null_connection )
{
  BOOST_CHECK_THROW(
    PsqlTools::PostgresPQ::Transaction object_uder_test( nullptr )
  , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_CASE( sql_execute )
{
  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );
  std::shared_ptr< pg_conn > connection( connection_ptr, [](pg_conn*){} );

  static constexpr auto sql = "SELECT * FROM table";

  // 1. check status
  EXPECT_CALL( *m_pq_mock, PQresultStatus( ::testing::_ ) )
    .WillRepeatedly( Return( PGRES_COMMAND_OK ) ) // every execute will success
  ;

  // 2. executes
  EXPECT_CALL( *m_pq_mock, PQexec( ::testing::_, ::testing::_ ) ).Times(2); //c_tor, d_tor
  EXPECT_CALL( *m_pq_mock, PQexec( ::testing::_, ::testing::StrEq( sql ) ) ).Times(1);


  PsqlTools::PostgresPQ::Transaction object_uder_test( connection );

  BOOST_CHECK_NO_THROW( object_uder_test.execute( sql ) );
}

BOOST_AUTO_TEST_CASE( negative_sql_execute )
{
  pg_conn* connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ) );
  std::shared_ptr< pg_conn > connection( connection_ptr, [](pg_conn*){} );

  static constexpr auto sql = "SELECT * FROM table";

  {
    ::testing::InSequence seq;

    EXPECT_CALL(*m_pq_mock, PQexec(::testing::_, ::testing::_)).Times(1); //c_tor
    EXPECT_CALL(*m_pq_mock, PQresultStatus(::testing::_)).Times(1).WillOnce(Return(PGRES_COMMAND_OK)); // c_tor

    EXPECT_CALL(*m_pq_mock, PQexec(::testing::_, ::testing::StrEq(sql))).Times(1); // TEST EXECUTE
    EXPECT_CALL(*m_pq_mock, PQresultStatus(::testing::_)).Times(1).WillOnce(Return(PGRES_FATAL_ERROR)); // TEST EXECUTE

    EXPECT_CALL(*m_pq_mock, PQexec(::testing::_, ::testing::_)).Times(1); //c_tor, d_tor
    EXPECT_CALL(*m_pq_mock, PQresultStatus(::testing::_)).Times(1).WillOnce(Return(PGRES_COMMAND_OK)); // for d_tor
  }

  PsqlTools::PostgresPQ::Transaction object_uder_test( connection );

  BOOST_CHECK_THROW( object_uder_test.execute( sql ), std::runtime_error );
}


BOOST_AUTO_TEST_SUITE_END()