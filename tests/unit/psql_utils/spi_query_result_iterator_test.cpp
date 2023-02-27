#include "spi_select_result_iterator.hpp"

#include <boost/test/unit_test.hpp>

#include "mock/spi_mock.hpp"

#include "include/psql_utils/postgres_includes.hpp"
#include "include/psql_utils/spi_session.hpp"
#include "include/exceptions.hpp"

BOOST_AUTO_TEST_SUITE( spi_query_result_iterator )

BOOST_AUTO_TEST_CASE( positive_creation ) {
  auto spi_mock = SpiMock::create_and_get();
  constexpr auto query = "SELECT * FROM TABLE";

  //1. SpiSession
  EXPECT_CALL(*spi_mock, SPI_connect()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));
  EXPECT_CALL(*spi_mock, SPI_finish()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));

  //2. SelectIterator
  EXPECT_CALL( *spi_mock, SPI_execute( ::testing::StrEq( query ), ::testing::_, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( SPI_OK_SELECT ) );

  EXPECT_CALL( *spi_mock, SPI_freetuptable( ::testing::_ ) )
    .Times( 1 );

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  auto it_under_test = PsqlTools::PsqlUtils::SelectResultIterator::create(session, query );

  BOOST_CHECK( it_under_test );
}

BOOST_AUTO_TEST_CASE( negative_creation_results_not_released ) {
  auto spi_mock = SpiMock::create_and_get();
  constexpr auto query = "SELECT * FROM TABLE";

  EXPECT_CALL(*spi_mock, SPI_connect()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));
  EXPECT_CALL(*spi_mock, SPI_finish()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));

  EXPECT_CALL( *spi_mock, SPI_execute( ::testing::StrEq( query ), ::testing::_, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( SPI_OK_SELECT ) );

  EXPECT_CALL( *spi_mock, SPI_freetuptable( ::testing::_ ) ).Times(1);

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  auto hold_result_it = PsqlTools::PsqlUtils::SelectResultIterator::create( session, query );

  BOOST_REQUIRE( hold_result_it );
  BOOST_CHECK_THROW(PsqlTools::PsqlUtils::SelectResultIterator::create( session, query ), std::runtime_error );
}

BOOST_AUTO_TEST_CASE( negative_creation_sql_error ) {
  auto spi_mock = SpiMock::create_and_get();
  constexpr auto query = "SELECT * FROM TABLE";

  EXPECT_CALL(*spi_mock, SPI_connect()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));
  EXPECT_CALL(*spi_mock, SPI_finish()).WillRepeatedly(::testing::Return(SPI_OK_CONNECT));

  EXPECT_CALL( *spi_mock, SPI_execute( ::testing::_, ::testing::_, ::testing::_ ) )
    .Times( 1 )
    .WillOnce( ::testing::Return( SPI_ERROR_UNCONNECTED ) );

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  BOOST_CHECK_THROW(PsqlTools::PsqlUtils::SelectResultIterator::create(session, query ), PsqlTools::ObjectInitializationException );
}

BOOST_AUTO_TEST_CASE( negative_creation_wrong_session ) {
  auto spi_mock = SpiMock::create_and_get();
  constexpr auto query = "SELECT * FROM TABLE";

  BOOST_CHECK_THROW(PsqlTools::PsqlUtils::SelectResultIterator::create(nullptr, query ), PsqlTools::ObjectInitializationException );
}

BOOST_AUTO_TEST_SUITE_END()
