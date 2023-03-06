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

class StringOption : public CustomConfiguration::OptionBase {
    public:
      char* m_value;
  };

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

} // namespace PsqlTools::PsqlUtils
