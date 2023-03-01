#pragma once

#include <memory>
#include <string>

namespace PsqlTools::PsqlUtils {
  class SpiSession;
} // PsqlTools::PsqlUtils

namespace PsqlTools::QuerySupervisor {
  /* The object of this type is a global variable in initialization.hpp
   * In its ctro db is initialized and prepared to work with fork extenstion
   * Please add all db initialization inside the ctor
   */
  class Initializer {
  public:
      Initializer();
      ~Initializer() = default;
      Initializer( const Initializer& ) = delete;
      Initializer( const Initializer&& ) = delete;
      Initializer& operator=( const Initializer& ) = delete;
      Initializer& operator=( Initializer&& ) = delete;

  private:
    std::shared_ptr< PsqlTools::PsqlUtils::SpiSession > m_spi_session;
  };
} // namespace PsqlTools::ForkExtension
