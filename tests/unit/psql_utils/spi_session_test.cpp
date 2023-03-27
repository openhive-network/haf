#include <boost/test/unit_test.hpp>

#include "mock/spi_mock.hpp"

#include "psql_utils/spi_session.hpp"
#include "psql_utils/postgres_includes.hpp"
#include "include/exceptions.hpp"

using namespace PsqlTools;
using ::testing::Return;
using ::testing::InSequence;
using ::testing::StrEq;
using ::testing::_;

BOOST_AUTO_TEST_SUITE( spi_session )

BOOST_AUTO_TEST_CASE( positivie_session_create_and_destroy )
{
  auto spi_mock = SpiMock::create_and_get();
  {
    InSequence seq;
    EXPECT_CALL(*spi_mock, SPI_connect())
            .Times(1)
            .WillOnce(Return(SPI_OK_CONNECT));

    EXPECT_CALL(*spi_mock, SPI_finish())
            .Times(1)
            .WillOnce(Return(SPI_OK_CONNECT));
  }

  BOOST_CHECK_NO_THROW( PsqlTools::PsqlUtils::SpiSession::create() );
}

BOOST_AUTO_TEST_CASE( positivie_singleton_check )
{
  auto spi_mock = SpiMock::create_and_get();
  {
    InSequence seq;
    EXPECT_CALL(*spi_mock, SPI_connect())
      .Times(1)
      .WillOnce(Return(SPI_OK_CONNECT));

    EXPECT_CALL(*spi_mock, SPI_finish())
      .Times(1)
      .WillOnce(Return(SPI_OK_CONNECT));
  }

  auto session1 = PsqlTools::PsqlUtils::SpiSession::create();
  auto session2 = PsqlTools::PsqlUtils::SpiSession::create();
  BOOST_CHECK_EQUAL( session1, session2 );
}

BOOST_AUTO_TEST_CASE( negative_session_create )
{
  auto spi_mock = SpiMock::create_and_get();
  EXPECT_CALL(*spi_mock, SPI_connect())
          .Times(1)
          .WillOnce(Return(SPI_ERROR_CONNECT));

  BOOST_CHECK_THROW( PsqlTools::PsqlUtils::SpiSession::create(), ObjectInitializationException );
}

BOOST_AUTO_TEST_CASE( negative_session_close )
{
  auto spi_mock = SpiMock::create_and_get();
  EXPECT_CALL(*spi_mock, SPI_connect())
          .Times(1)
          .WillOnce(Return(SPI_OK_CONNECT));

  EXPECT_CALL(*spi_mock, SPI_finish())
          .Times(1)
          .WillOnce(Return(SPI_ERROR_UNCONNECTED));

  BOOST_CHECK_NO_THROW( PsqlTools::PsqlUtils::SpiSession::create() ); // cannot throw from d_tor
}

BOOST_AUTO_TEST_CASE( positive_execute_util )
{
  auto spi_mock = SpiMock::create_and_get();
  constexpr auto query = "CREATE TABLE ABC(id INTEGER)";

  EXPECT_CALL(*spi_mock, SPI_connect())
    .Times(1)
    .WillOnce(Return(SPI_OK_CONNECT));

  EXPECT_CALL(*spi_mock, SPI_finish())
    .Times(1)
    .WillOnce(Return(SPI_OK_CONNECT));

  EXPECT_CALL( *spi_mock, SPI_execute( StrEq( query ), false, _ ) )
    .Times(1)
    .WillOnce(Return(SPI_OK_UTILITY));

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  BOOST_CHECK_NO_THROW( session->executeUtil( query ) );
}

BOOST_AUTO_TEST_CASE( negative_execute_util )
{
  auto spi_mock = SpiMock::create_and_get();
  constexpr auto query = "CREATE TABLE ABC(id INTEGER)";

  EXPECT_CALL(*spi_mock, SPI_connect())
    .Times(1)
    .WillOnce(Return(SPI_OK_CONNECT));

  EXPECT_CALL(*spi_mock, SPI_finish())
    .Times(1)
    .WillOnce(Return(SPI_OK_CONNECT));

  EXPECT_CALL( *spi_mock, SPI_execute( StrEq( query ), false, _ ) )
    .Times(1)
    .WillOnce(Return(SPI_ERROR_UNCONNECTED));

  auto session = PsqlTools::PsqlUtils::SpiSession::create();
  BOOST_CHECK_THROW( session->executeUtil( query ), std::runtime_error );
}

BOOST_AUTO_TEST_SUITE_END()

