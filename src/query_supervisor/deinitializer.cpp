#include "deinitializer.hpp"

#include "include/exceptions.hpp"
#include "include/psql_utils/postgres_includes.hpp"
#include "include/psql_utils/spi_session.hpp"

#include <string>
#include <unistd.h>

using namespace std::string_literals;

namespace PsqlTools::QuerySupervisor {

  Deinitializer::Deinitializer() try {
    m_spi_session = PsqlTools::PsqlUtils::SpiSession::create();
  }
  catch ( std::exception& _exception ) {
    LOG_ERROR( "Unhandled exception: %s", _exception.what() );
  }
  catch( ... ) {
    LOG_ERROR( "Unhandled unknown exception" );
  }

} // namespace PsqlTools::ForkExtension
