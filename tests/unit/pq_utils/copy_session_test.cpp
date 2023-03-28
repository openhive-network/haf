#include <boost/test/unit_test.hpp>

#include "mock/pq_mock.hpp"
#include "mock/gmock_fixture.hpp"

#include "pq_utils/copy_session.hpp"
#include "include/exceptions.hpp"

using ::testing::Return;

BOOST_FIXTURE_TEST_SUITE( copy_session, GmockFixture )

BOOST_AUTO_TEST_CASE( positivie_copy_session )
{
  static constexpr auto db_name = "test_db";
  static constexpr auto expected_copy_sql = "COPY test_db FROM STDIN binary";

  std::shared_ptr< pg_conn > connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ), [](pg_conn*){} );
  PGresult* copy_result_ptr( reinterpret_cast< PGresult* >( 0xAAAAAAAAAAAAAAAA ) );

  // 1. execute COPY sql command
  EXPECT_CALL( *m_pq_mock, PQexec( connection_ptr.get(), ::testing::StrEq( expected_copy_sql ) ) )
          .Times(1)
          .WillOnce( Return( copy_result_ptr ) )
          ;
  // 2. chceck COPY result
  EXPECT_CALL( *m_pq_mock, PQresultStatus( copy_result_ptr ) )
          .Times(1)
          .WillOnce( Return( PGRES_COPY_IN ) )
          ;

  // 3. don't forget to clear status
  EXPECT_CALL( *m_pq_mock, PQclear( copy_result_ptr ) )
          .Times(1);

  // 4. finish copy session
  EXPECT_CALL( *m_pq_mock, PQputCopyEnd( connection_ptr.get(), ::testing::_ ) )
          .Times(1)
  ;

  BOOST_CHECK_NO_THROW( PsqlTools::PostgresPQ::CopySession session_under_test( connection_ptr, db_name, {} ) );
}

BOOST_AUTO_TEST_CASE( positivie_copy_session_with_columns )
{
  static constexpr auto db_name = "test_db";
  const std::vector< std::string > columns = { "column1", "column2", "column3" };
  static constexpr auto expected_copy_sql = "COPY test_db(column1,column2,column3) FROM STDIN binary";

  std::shared_ptr< pg_conn > connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ), [](pg_conn*){} );
  PGresult* copy_result_ptr( reinterpret_cast< PGresult* >( 0xAAAAAAAAAAAAAAAA ) );

  // 1. execute COPY sql command
  EXPECT_CALL( *m_pq_mock, PQexec( connection_ptr.get(), ::testing::StrEq( expected_copy_sql ) ) )
          .Times(1)
          .WillOnce( Return( copy_result_ptr ) )
          ;
  // 2. chceck COPY result
  EXPECT_CALL( *m_pq_mock, PQresultStatus( copy_result_ptr ) )
          .Times(1)
          .WillOnce( Return( PGRES_COPY_IN ) )
          ;

  // 3. don't forget to clear status
  EXPECT_CALL( *m_pq_mock, PQclear( copy_result_ptr ) )
          .Times(1);

  // 4. finish copy session
  EXPECT_CALL( *m_pq_mock, PQputCopyEnd( connection_ptr.get(), ::testing::_ ) )
          .Times(1)
          ;

  BOOST_CHECK_NO_THROW(
    PsqlTools::PostgresPQ::CopySession session_under_test( connection_ptr, db_name, columns )
  );
}

BOOST_AUTO_TEST_CASE( negative_copy_session_cannot_start )
{
  std::shared_ptr< pg_conn > connection_ptr( reinterpret_cast< pg_conn* >( 0xFFFFFFFFFFFFFFFF ), [](pg_conn*){} );

  // 1. chceck COPY result
  EXPECT_CALL( *m_pq_mock, PQresultStatus( ::testing::_ ) )
          .Times(1)
          .WillOnce( Return( PGRES_FATAL_ERROR ) )
          ;

  // 2. don't forget to clear status
  EXPECT_CALL( *m_pq_mock, PQclear( ::testing::_ ) )
          .Times(1);

  BOOST_CHECK_THROW(
      PsqlTools::PostgresPQ::CopySession session_under_test( connection_ptr, "base", {} )
    , PsqlTools::ObjectInitializationException
  );
}

BOOST_AUTO_TEST_SUITE_END()
