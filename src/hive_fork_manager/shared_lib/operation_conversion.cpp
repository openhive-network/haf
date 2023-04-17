#include <operation_conversion.hpp>

#include <fc/exception/exception.hpp>
#include <fc/io/json.hpp>
#include <fc/io/raw.hpp>
#include <fc/variant.hpp>

hive::protocol::operation raw_to_operation( const char* raw_data, uint32 data_length )
{
  if( !data_length )
    return {};

  return fc::raw::unpack_from_char_array< hive::protocol::operation >( raw_data, static_cast< uint32_t >( data_length ) );
}

fc::variant raw_to_variant_impl( const char* raw_data, uint32 data_length )
{
  if( !data_length )
    return {};

  using hive::protocol::operation;

  operation op = fc::raw::unpack_from_char_array< operation >( raw_data, static_cast< uint32_t >( data_length ) );

  fc::variant v;
  fc::to_variant( op, v );

  return v;
}

std::string raw_to_json( const char* raw_data, uint32 data_length )
{
  return fc::json::to_string( raw_to_variant_impl( raw_data, data_length ) );
}
