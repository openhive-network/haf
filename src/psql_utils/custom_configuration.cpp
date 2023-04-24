#include "psql_utils/custom_configuration.h"

#include "include/exceptions.hpp"

#include "psql_utils/postgres_includes.hpp"

#include <limits>

namespace PsqlTools::PsqlUtils {

  CustomConfiguration::CustomConfiguration( std::string _prefix )
    : m_prefix(std::move(_prefix)) {
  }

  /*CustomConfiguration::~CustomConfiguration(){
  }*/

  void CustomConfiguration::addStringOption(
      const std::string& _name
    , const std::string& _shortDescription
    , const std::string& _longDescription
    , const std::string& _defaultValue
  ) {
    using namespace std::string_literals;
    OptionPlaceholder newOption( new char*( const_cast<char*>("") ) ); // dont worry about memory lifetime, option has to live as long as backend

    if ( m_options.find( _name ) != m_options.end() ) {
      THROW_INITIALIZATION_ERROR( "Option already exists: "s + _name );
    }

    DefineCustomStringVariable(
        ( m_prefix + "." + _name ).c_str()
      , _shortDescription.c_str()
      , _longDescription.c_str()
      , std::get<char**>(newOption)
      , _defaultValue.c_str()
      , GucContext::PGC_SUSET
      , 0
      , nullptr, nullptr, nullptr
    );

    m_options.emplace( _name, newOption );
  }

  void CustomConfiguration::addPositiveIntOption(
      const std::string& _name
    , const std::string& _shortDescription
    , const std::string& _longDescription
    , uint32_t _defaultValue
  ) {
    using namespace std::string_literals;
    /**
     * trick: postgres uses only int, so we allocate int
     */
    OptionPlaceholder newOption( new PositiveInt );

    if ( _defaultValue > std::numeric_limits< int >::max() ) {
      THROW_INITIALIZATION_ERROR( "Default value of option "s + _name + " is to big." );
    }

    if ( m_options.find( _name ) != m_options.end() ) {
      THROW_INITIALIZATION_ERROR( "Option already exists: "s + _name );
    }

    DefineCustomIntVariable(
      ( m_prefix + "." + _name ).c_str()
      , _shortDescription.c_str()
      , _longDescription.c_str()
      , &std::get< PositiveInt* >( newOption )->m_value
      , static_cast< int >( _defaultValue )
      , 0
      , std::numeric_limits< int >::max()
      , GucContext::PGC_SUSET
      , 0
      , nullptr, nullptr, nullptr
    );

    m_options.emplace( _name, newOption );
  }

  void CustomConfiguration::addIntOption(
      const std::string& _name
    , const std::string& _shortDescription
    , const std::string& _longDescription
    , int _defaultValue
  ) {
    using namespace std::string_literals;
    OptionPlaceholder newOption( new int( std::numeric_limits< int >::infinity() )  );

    if ( m_options.find( _name ) != m_options.end() ) {
      THROW_INITIALIZATION_ERROR( "Option already exists: "s + _name );
    }

    DefineCustomIntVariable(
        ( m_prefix + "." + _name ).c_str()
      , _shortDescription.c_str()
      , _longDescription.c_str()
      , std::get< int* >( newOption )
      , _defaultValue
      , std::numeric_limits< int >::min()
      , std::numeric_limits< int >::max()
      , GucContext::PGC_SUSET
      , 0
      , nullptr, nullptr, nullptr
    );

    m_options.emplace( _name, newOption );
  }


  void CustomConfiguration::addBooleanOption(
      const std::string& _name
    , const std::string& _shortDescription
    , const std::string& _longDescription
    , bool _defaultValue
  ) {
    using namespace std::string_literals;
    OptionPlaceholder newOption( new bool( _defaultValue )  );

    if ( m_options.find( _name ) != m_options.end() ) {
      THROW_INITIALIZATION_ERROR( "Option already exists: "s + _name );
    }

    DefineCustomBoolVariable(
        ( m_prefix + "." + _name ).c_str()
      , _shortDescription.c_str()
      , _longDescription.c_str()
      , std::get< bool* >( newOption )
      , _defaultValue
      , GucContext::PGC_SUSET
      , 0
      , nullptr, nullptr, nullptr
    );

    m_options.emplace( _name, newOption );
  }

  std::string CustomConfiguration::getOptionAsString(const std::string& _name ) const {
    // Warning: it can be used only in backend main thread because static variable is used to pass a result
    using namespace std::string_literals;
    auto value = GetConfigOption( ( m_prefix + "." + _name ).c_str(), false, false );
    if ( value == nullptr ) {
      THROW_RUNTIME_ERROR( "No configuration option "s +  m_prefix + "."s + _name );
    }
    return value;
  }

  CustomConfiguration::Option
  CustomConfiguration::getOption( const std::string& _name ) const {
    using namespace std::string_literals;
    auto optionIt = m_options.find( _name );

    if ( optionIt == m_options.end() ) {
      THROW_RUNTIME_ERROR( "No configuration option "s +  m_prefix + "."s + _name );
    }

    return std::visit( [](auto arg){ return Option( *arg ); }, optionIt->second );
  }

} // namespace PsqlTools::PsqlUtils
