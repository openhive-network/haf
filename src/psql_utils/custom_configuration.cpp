#include "include/psql_utils/custom_configuration.h"

#include "include/exceptions.hpp"

#include "include/psql_utils/postgres_includes.hpp"

namespace PsqlTools::PsqlUtils {

  class CustomConfiguration::OptionBase{
  public:
    virtual ~OptionBase() = default;
  protected:
    OptionBase() = default;

    OptionBase& operator=(const OptionBase&) = delete;
    OptionBase(const OptionBase&) = delete;
    OptionBase& operator=(const OptionBase&&) = delete;
    OptionBase(const OptionBase&&) = delete;
  };

  // here are defined memory placeholders for configuration options
  class StringOption : public CustomConfiguration::OptionBase {
      public:
        char* m_value;
  };

  CustomConfiguration::CustomConfiguration( std::string _prefix )
    : m_prefix(std::move(_prefix)) {
  }

  CustomConfiguration::~CustomConfiguration(){
  }

  void CustomConfiguration::addStringOption(
      const std::string& _name
    , const std::string& _shortDescription
    , const std::string& _longDescription
    , const std::string& _defaultValue
  ) {
    using namespace std::string_literals;
    auto newOption = std::make_unique<StringOption>();

    DefineCustomStringVariable(
        ( m_prefix + "." + _name ).c_str()
      , _shortDescription.c_str()
      , _longDescription.c_str()
      , &newOption->m_value
      , _defaultValue.c_str()
      , GucContext::PGC_SIGHUP
      , 0
      , nullptr, nullptr, nullptr
    );

    if ( m_options.find( _name ) != m_options.end() ) {
      THROW_INITIALIZATION_ERROR( "Option already exists: "s + _name );
    }

    m_options.emplace( _name, std::move(newOption) );
  }

  std::string CustomConfiguration::getOptionValue( const std::string& _name ) const {
    // Warning: it can be used only in backend main thread because static variable is used to pass a result
    std::string value = GetConfigOption( ( m_prefix + "." + _name ).c_str(), false, false );
    return value;
  }

} // namespace PsqlTools::PsqlUtils
