#pragma once

#include <cassert>
#include <limits>
#include <memory>
#include <string>
#include <unordered_map>
#include <variant>

namespace PsqlTools::PsqlUtils {

  /**
   * @brief Configuration option can only be changed by the changes in postgres configuration or by superuser
   * The class is intended to be wrapped by specific module configuration object which will control option  types and names
   * Options are named with convention: prefix.option_name
   */

  class CustomConfiguration {
    public:
      // define configuration entry prefix for a module
      CustomConfiguration( std::string _prefix );
      ~CustomConfiguration() = default;

      void addStringOption(
          const std::string& _name
        , const std::string& _shortDescription
        , const std::string& _longDescription
        , const std::string& _defaultValue = std::string()
          );

      void addPositiveIntOption(
          const std::string& _name
        , const std::string& _shortDescription
        , const std::string& _longDescription
        , uint32_t _defaultValue
      );

      void addIntOption(
          const std::string& _name
        , const std::string& _shortDescription
        , const std::string& _longDescription
        , int _defaultValue
      );

      /**
       * @brief may throw std::runtime_error when option does not exist
       * it uses postgres api to get the option
       * user is responsible to cast string to a given value type
       *
       * @return option value as string
       * @throw std::runtime_error when option is unknown
       */
      std::string getOptionAsString(const std::string& _name ) const;

      /**
       * @brief Return option from memory without calling postgres api
       * no conversion from string is required, however user needs to
       * know what kind of option type is expected and get it from the returned variant
       *
       * @return return variant with given option
       * @throw std::runtime_error when option is unknown
       */

      using  Option = std::variant< std::string, int32_t, uint32_t >;
      Option getOption( const std::string& _name ) const;
    private:
      const std::string m_prefix;
      struct PositiveInt {
        int m_value = std::numeric_limits< int >::infinity();
        operator uint32_t() const { assert( m_value >= 0 ); return static_cast<uint32_t>(m_value); }
      };
      using  OptionPlaceholder = std::variant< char**, int32_t*, PositiveInt* >;

      std::unordered_map< std::string, OptionPlaceholder > m_options;
  };

} // namespace PsqlTools::PsqlUtils
