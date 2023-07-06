#pragma once

#include "mock/postgres_mock.hpp"
#include "mock/pq_mock.hpp"
#include "mock/spi_mock.hpp"

#include <boost/test/unit_test.hpp>


/**
 *  All the test which use GMOCK with boost unit tests shall use this fixture
 *  otherwise lack of expectations calls will produce only output without test failure
 */
struct GmockFixture {
  GmockFixture() {
    m_postgres_mock = PostgresMock::create_and_get();
    m_spi_mock = SpiMock::create_and_get();
    m_pq_mock = PqMock::create_and_get();
  }

  virtual ~GmockFixture() {
    BOOST_REQUIRE( ::testing::Mock::VerifyAndClear( m_postgres_mock.get() ) );
    BOOST_REQUIRE( ::testing::Mock::VerifyAndClear( m_spi_mock.get() ) );
    BOOST_REQUIRE( ::testing::Mock::VerifyAndClear( m_pq_mock.get() ) );

    m_postgres_mock.reset();
  }

  std::shared_ptr<PostgresMock> m_postgres_mock;
  std::shared_ptr<SpiMock> m_spi_mock;
  std::shared_ptr<PqMock> m_pq_mock;
};