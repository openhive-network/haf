#pragma once

#include <memory>
#include <string>

namespace PsqlTools::PsqlUtils {
  class SpiSession;
} // PsqlTools::PsqlUtils

namespace PsqlTools::ForkExtension {
  /* The object of tit stathis type is a global variable in initialization.hpp
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
      void initialize_tuples_table() const;
      void initialize_back_from_fork_function() const;

      bool function_exists( const std::string& _function_name ) const;
      void initialize_function( const std::string& _function_name, const std::string& _sql_return_type ) const;

  private:
    std::shared_ptr< PsqlTools::PsqlUtils::SpiSession > m_spi_session;
  };
} // namespace PsqlTools::ForkExtension
