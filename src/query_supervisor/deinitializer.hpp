#pragma once

#include <memory>
#include <string>

namespace PsqlTools::PsqlUtils {
  class SpiSession;
} // PsqlTools::PsqlUtils

namespace PsqlTools::QuerySupervisor {
  /* In its ctro db is initialized and prepared to work with fork extenstion
   * Please add all db deinitialization inside the ctor
   */
  class Deinitializer {
  public:
      Deinitializer();
      ~Deinitializer() = default;
      Deinitializer( const Deinitializer& ) = delete;
      Deinitializer( const Deinitializer&& ) = delete;
      Deinitializer& operator=( const Deinitializer& ) = delete;
      Deinitializer& operator=( Deinitializer&& ) = delete;

  private:
    std::shared_ptr< PsqlTools::PsqlUtils::SpiSession > m_spi_session;
  };
} // namespace PsqlTools::ForkExtension
