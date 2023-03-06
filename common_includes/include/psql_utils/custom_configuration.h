#pragma once

#include <string>
#include <memory>
#include <unordered_map>

namespace PsqlTools::PsqlUtils {

  //Configuration option can only be changed by the changes in postgres configuration file
  //Option name: _prefix._name
  class CustomConfiguration final {
    public:
      // define configuration entry prefix for a module
      CustomConfiguration( std::string _prefix );
      ~CustomConfiguration();

      void addStringOption(
          const std::string& _name
        , const std::string& _shortDescription
        , const std::string& _longDescription
        , const std::string& _defaultValue = std::string()
          );

      std::string getOptionValue( const std::string& _name ) const;
      class OptionBase;
    private:
      const std::string m_prefix;

      using Option = std::unique_ptr< OptionBase >;
      std::unordered_map< std::string, Option > m_options;
  };

} // namespace PsqlTools::PsqlUtils
