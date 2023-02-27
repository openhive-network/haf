#pragma once

#include "include/psql_utils/logger.hpp"

#include <stdexcept>
#include <string>

#define THROW_RUNTIME_ERROR( _message )                                          \
LOG_WARNING( "Throw exception: %s",  std::string( _message ).c_str() );          \
throw std::runtime_error( _message )                                             \

#define THROW_INITIALIZATION_ERROR( _message )                                        \
LOG_WARNING( "Throw inialization exception: %s", std::string( _message ).c_str() );   \
throw ObjectInitializationException( _message )                                       \


namespace PsqlTools {

// All custom C++ object may throws this exception formtheirs c-tors to implement RAII
class ObjectInitializationException : public std::runtime_error
{
public:
    explicit ObjectInitializationException( const std::string& _message ) : std::runtime_error( _message ){}
    ~ObjectInitializationException() = default;
};

} // namespace PsqlTools

