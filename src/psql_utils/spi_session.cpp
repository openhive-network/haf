#include "include/psql_utils/spi_session.hpp"

#include "include/psql_utils/postgres_includes.hpp"
#include "spi_select_result_iterator.hpp"
#include "include/exceptions.hpp"

namespace {
  std::weak_ptr< PsqlTools::PsqlUtils::SpiSession > SPI_SESSION;
}

using namespace std::string_literals;

namespace PsqlTools::PsqlUtils {
  SpiSession::SpiSession() {
    if ( SPI_connect() != SPI_OK_CONNECT ) {
      THROW_INITIALIZATION_ERROR( "Cannot connect to SPI" );
    }
  }

  SpiSession::~SpiSession() {
    SPI_finish();
  }

  std::shared_ptr< SpiSession >
  SpiSession::create()
  {
    auto instance = SPI_SESSION.lock();
    if ( instance ) {
      return instance;
    }

    std::shared_ptr< SpiSession > new_session( new SpiSession() );
    SPI_SESSION = new_session;
    return new_session;
  }

  std::shared_ptr< ISelectResult >
  SpiSession::executeSelect( std::string _select_query ) const {
    auto instance = SPI_SESSION.lock();
    assert( instance );

    return SelectResultIterator::create( instance, _select_query );
  }

  void
  SpiSession::executeUtil(const std::string& _query ) const {
    if ( SPI_execute( _query.c_str(), false, 0 ) != SPI_OK_UTILITY ) {
      THROW_RUNTIME_ERROR( "Cannot execute query : "s + _query );
    }
  }
} // namespace PsqlTools::PsqlUtils
