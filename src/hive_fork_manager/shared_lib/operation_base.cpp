#include "operation_base.hpp"

#include "to_jsonb.hpp"
#include "svstream.hpp"

#include <psql_utils/postgres_includes.hpp>
#include <hive/protocol/operations.hpp>

#include <fc/exception/exception.hpp>

#include <fc/io/datastream.hpp>
#include <fc/io/buffered_iostream.hpp>
#include <fc/io/json.hpp>
#include <fc/io/raw.hpp>

#include <cstring>
#include <string>
#include <vector>

namespace {

hive::protocol::operation raw_to_operation( const char* raw_data, uint32 data_length )
{
  if( !data_length )
    return {};

  return fc::raw::unpack_from_char_array< hive::protocol::operation >( raw_data, static_cast< uint32_t >( data_length ) );
}

fc::variant op_to_variant_impl( const char* raw_data, uint32 data_length )
{
  if( !data_length )
    return {};

  using hive::protocol::operation;

  operation op = fc::raw::unpack_from_char_array< operation >( raw_data, static_cast< uint32_t >( data_length ) );

  fc::variant v;
  fc::to_variant( op, v );

  return v;
}

std::string op_to_json( const char* raw_data, uint32 data_length )
{
  try
  {
    return fc::json::to_string( op_to_variant_impl( raw_data, data_length ) );
  }
  catch( const fc::exception& e )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( "%s", e.to_string().c_str() ) ) );
    return {};
  }
  catch( ... )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( "Unexpected binary to text conversion occurred" ) ) );
    return {};
  }
}

std::vector< char > json_to_op( const char* raw_data )
{
  try
  {
    if( *raw_data == '\0' )
      return {};

    auto bufstream = fc::buffered_istream( fc::make_svstream( raw_data ) );
    fc::variant v = fc::json::from_stream( bufstream );

    hive::protocol::operation op;
    fc::from_variant( v, op );

    return fc::raw::pack_to_vector( op );
  }
  catch( const fc::exception& e )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_TEXT_REPRESENTATION ), errmsg( "%s", e.to_string().c_str() ) ) );
    return {};
  }
  catch( ... )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_TEXT_REPRESENTATION ), errmsg( "Unexpected text to binary conversion occurred" ) ) );
    return {};
  }
}

void validate_raw_data( const char* raw_data, size_t data_length )
{
    try
    {
      raw_to_operation( raw_data, data_length );
    }
    catch( const fc::exception& e )
    {
      ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( "%s", e.to_string().c_str() ) ) );
    }
    catch( const std::exception& e )
    {
      ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( "%s", e.what() ) ) );
    }
    catch( ... )
    {
      ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( "Unexpected binary to operation conversion occurred" ) ) );
    }
}

} // namespace

extern "C"
{
  PG_MODULE_MAGIC;

  _operation* make_operation( const char* raw_data, uint32 data_length )
  {
    _operation* op = (_operation*) palloc( data_length + VARHDRSZ ); // Alocate with the header
    SET_VARSIZE( op, data_length + VARHDRSZ );                       // set in VARHDRSZ - set operation size

    memcpy( VARDATA( op ), raw_data, data_length ); // Allocate new bytea struct and copy given data to it

    return op;
  }

  int operation_cmp_impl( const _operation* lhs, const _operation* rhs )
  {
    if( VARSIZE_ANY_EXHDR( lhs ) > VARSIZE_ANY_EXHDR( rhs ) )
      return 1;
    else if( VARSIZE_ANY_EXHDR( lhs ) < VARSIZE_ANY_EXHDR( rhs ) )
      return -1;

    return memcmp( VARDATA_ANY( lhs ), VARDATA_ANY( rhs ), VARSIZE_ANY_EXHDR( lhs ) );
  }

  PG_FUNCTION_INFO_V1( operation_to_jsonb );
  Datum operation_to_jsonb( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    uint32 data_length = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    try
    {
      const hive::protocol::operation operation = raw_to_operation( raw_data, data_length );
      JsonbValue* jsonb = operation_to_jsonb_value(operation);

      PG_RETURN_POINTER(JsonbValueToJsonb(jsonb));
    }
    catch( const fc::exception& e )
    {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "%s", e.to_string().c_str() ) ) );
      return {};
    }
    catch( const std::exception& e )
    {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "%s", e.what() ) ) );
      return {};
    }
    catch( ... )
    {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "Could not convert operation to jsonb" ) ) );
      return {};
    }
  }

  PG_FUNCTION_INFO_V1( operation_from_jsonb );
  Datum operation_from_jsonb( PG_FUNCTION_ARGS )
  {
    Jsonb *jb = PG_GETARG_JSONB_P(0);
    // TODO: do smarter conversion that jsonb -> text -> fc::json -> operation
    const char* out = JsonbToCString(NULL, &jb->root, VARSIZE(jb));
    std::vector< char > data = json_to_op( out );

    PG_RETURN_HIVE_OPERATION( make_operation( data.data(), data.size() ) );
  }

  PG_FUNCTION_INFO_V1( operation_from_jsontext );
  Datum operation_from_jsontext( PG_FUNCTION_ARGS )
  {
    const text* str = PG_GETARG_TEXT_P( 0 );

    std::vector< char > data = json_to_op( text_to_cstring( str ) );

    PG_RETURN_HIVE_OPERATION( make_operation( data.data(), data.size() ) );
  }

  PG_FUNCTION_INFO_V1( operation_to_jsontext );
  Datum operation_to_jsontext( PG_FUNCTION_ARGS )
  {
    _operation* op       = PG_GETARG_HIVE_OPERATION_PP( 0 );
    uint32 data_length   = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    std::string json = op_to_json( raw_data, data_length );
    uint32 json_size = json.size() + 1;
    char* chars       = (char*) palloc( json_size );

    const char* cstring_out = (const char*) memcpy( chars, json.c_str(), json_size );
    PG_RETURN_TEXT_P(cstring_to_text(cstring_out));
  }

  PG_FUNCTION_INFO_V1( operation_in );
  Datum operation_in( PG_FUNCTION_ARGS )
  {
    const char* data = PG_GETARG_CSTRING( 0 );

    Datum bytes = DirectFunctionCall1(byteain, CStringGetDatum(data));
    validate_raw_data(VARDATA_ANY( bytes ), VARSIZE_ANY_EXHDR( bytes ));

    PG_RETURN_HIVE_OPERATION( make_operation( VARDATA_ANY( bytes ), VARSIZE_ANY_EXHDR( bytes ) ) );
  }

  PG_FUNCTION_INFO_V1( operation_out );
  Datum operation_out( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    Datum bytes = DirectFunctionCall1(byteaout, PointerGetDatum(op));
    PG_RETURN_CSTRING( bytes );
  }

  PG_FUNCTION_INFO_V1( operation_bin_in_internal );
  Datum operation_bin_in_internal( PG_FUNCTION_ARGS )
  {
    StringInfo buf = (StringInfo) PG_GETARG_POINTER( 0 ); // Should contain raw bytes

    // data and length should be eqeual to VARDATA_ANY and VARSIZE_ANY returned from the operation_bin_out
    PG_RETURN_HIVE_OPERATION( make_operation( buf->data, buf->len - 1 /* skip trailing null terminating byte */ ) );
  }

  PG_FUNCTION_INFO_V1( operation_bin_in );
  Datum operation_bin_in( PG_FUNCTION_ARGS )
  { // Same as operation_bin_in_internal, but accepts bytea instead of internal
    bytea* data          = PG_GETARG_BYTEA_PP( 0 );
    uint32 data_length   = VARSIZE_ANY_EXHDR( data );
    const char* raw_data = VARDATA_ANY( data );

    _operation* op = make_operation( raw_data, data_length );

    PG_RETURN_HIVE_OPERATION( op );
  }

  PG_FUNCTION_INFO_V1( operation_bin_out );
  Datum operation_bin_out( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );

    bytea* data = (bytea*) palloc( VARSIZE_ANY_EXHDR( op ) + VARHDRSZ );
    SET_VARSIZE( data, VARSIZE_ANY_EXHDR( op ) + VARHDRSZ );
    memcpy( VARDATA( data ), VARDATA_ANY( op ), VARSIZE_ANY_EXHDR( op ) );

    // Just postgres allocate and copy from the raw operation data
    PG_RETURN_BYTEA_P( data );
  }

  PG_FUNCTION_INFO_V1( operation_eq );
  Datum operation_eq( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) == 0 );
  }

  PG_FUNCTION_INFO_V1( operation_ne );
  Datum operation_ne( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) != 0 );
  }

  PG_FUNCTION_INFO_V1( operation_gt );
  Datum operation_gt( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) > 0 );
  }

  PG_FUNCTION_INFO_V1( operation_ge );
  Datum operation_ge( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) >= 0 );
  }

  PG_FUNCTION_INFO_V1( operation_lt );
  Datum operation_lt( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) < 0 );
  }

  PG_FUNCTION_INFO_V1( operation_le );
  Datum operation_le( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) <= 0 );
  }

  PG_FUNCTION_INFO_V1( operation_cmp );
  Datum operation_cmp( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_INT32( operation_cmp_impl( lhs, rhs ) );
  }
}
