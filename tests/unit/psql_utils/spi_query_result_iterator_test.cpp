#include "spi_select_result_iterator.hpp"

#include <boost/test/unit_test.hpp>

#include "mock/gmock_fixture.hpp"

#include "mock/spi_mock.hpp"

#include "psql_utils/postgres_includes.hpp"
#include "psql_utils/spi_session.hpp"
#include "include/exceptions.hpp"

BOOST_FIXTURE_TEST_SUITE( spi_query_result_iterator, GmockFixture )

BOOST_AUTO_TEST_CASE( positive_creation ) {
  constexpr auto query = "SELECT * FROM TABLE";

  //1. SpiSession
  EXPECT_CALL(*m_spi_mock, SPI_connect()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));
  EXPECT_CALL(*m_spi_mock, SPI_finish()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));

  //2. SelectIterator
  EXPECT_CALL( *m_spi_mock, SPI_execute( ::testing::StrEq( query ), ::testing::_, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( SPI_OK_SELECT ) );

  EXPECT_CALL( *m_spi_mock, SPI_freetuptable( ::testing::_ ) )
    .Times( 1 );

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  auto it_under_test = PsqlTools::PsqlUtils::SelectResultIterator::create(session, query );

  BOOST_CHECK( it_under_test );
}

BOOST_AUTO_TEST_CASE( negative_creation_results_not_released ) {
  constexpr auto query = "SELECT * FROM TABLE";

  EXPECT_CALL(*m_spi_mock, SPI_connect()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));
  EXPECT_CALL(*m_spi_mock, SPI_finish()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));

  EXPECT_CALL( *m_spi_mock, SPI_execute( ::testing::StrEq( query ), ::testing::_, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( SPI_OK_SELECT ) );

  EXPECT_CALL( *m_spi_mock, SPI_freetuptable( ::testing::_ ) ).Times(1);

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  auto hold_result_it = PsqlTools::PsqlUtils::SelectResultIterator::create( session, query );

  BOOST_REQUIRE( hold_result_it );
  BOOST_CHECK_THROW(PsqlTools::PsqlUtils::SelectResultIterator::create( session, query ), std::runtime_error );
}

BOOST_AUTO_TEST_CASE( negative_creation_sql_error ) {
  constexpr auto query = "SELECT * FROM TABLE";

  EXPECT_CALL(*m_spi_mock, SPI_connect()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));
  EXPECT_CALL(*m_spi_mock, SPI_finish()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));

  EXPECT_CALL( *m_spi_mock, SPI_execute( ::testing::_, ::testing::_, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( SPI_ERROR_UNCONNECTED ) );

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  BOOST_CHECK_THROW(PsqlTools::PsqlUtils::SelectResultIterator::create(session, query ), PsqlTools::ObjectInitializationException );
}

BOOST_AUTO_TEST_CASE( negative_creation_wrong_session ) {
  constexpr auto query = "SELECT * FROM TABLE";

  BOOST_CHECK_THROW(PsqlTools::PsqlUtils::SelectResultIterator::create(nullptr, query ), PsqlTools::ObjectInitializationException );
}

BOOST_AUTO_TEST_SUITE_END()
