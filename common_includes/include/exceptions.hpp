#pragma once

#include "psql_utils/logger.hpp"

#include <stdexcept>
#include <string>

#define THROW_RUNTIME_ERROR( _message )                                          \
LOG_WARNING( "Throw exception: %s",  std::string( _message ).c_str() );          \
throw std::runtime_error( _message )                                             \

/**
 * THROW_INITIALIZATION_ERROR macro to implement RAII pattern
 *
 * This macro throws an ObjectInitializationException when an object
 * can't be created, usually due to resource access issues. While this
 * is a serious problem for the object, it might not be as critical
 * for the client code. The macro logs the exception with DEBUG severity
 * to help with debugging.
 */
#define THROW_INITIALIZATION_ERROR( _message )                                        \
LOG_DEBUG( "Throw initialization exception: %s", std::string( _message ).c_str() );   \
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

