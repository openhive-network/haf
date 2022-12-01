#include "pq_operation_base.hpp"

#include <hive/protocol/operations.hpp>

#include <fc/exception/exception.hpp>
#include <fc/io/datastream.hpp>
#include <fc/io/json.hpp>
#include <fc/io/raw.hpp>
#include <fc/io/varint.hpp>

#include <cstring>
#include <string>
#include <vector>

namespace {

std::string op_to_json( const char* raw_data, uint32 data_length )
{
  try
  {
    if( !data_length )
      return {};

    using hive::protocol::operation;

    operation op = fc::raw::unpack_from_char_array< operation >( raw_data, static_cast< uint32_t >( data_length ) );

    fc::variant v;
    fc::to_variant( op, v );

    return fc::json::to_string( v );
  }
  catch( const fc::exception& e )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( e.to_string().c_str() ) ) );
    return {};
  }
  catch( ... )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( "Unexpected binary to text conversion occured" ) ) );
    return {};
  }
}

std::vector< char > json_to_op( const char* raw_data )
{
  try
  {
    if( *raw_data == '\0' )
      return {};

    fc::variant v = fc::json::from_string( std::string{ raw_data } );

    hive::protocol::operation op;
    fc::from_variant( v, op );

    return fc::raw::pack_to_vector( op );
  }
  catch( const fc::exception& e )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_TEXT_REPRESENTATION ), errmsg( e.to_string().c_str() ) ) );
    return {};
  }
  catch( ... )
  {
    ereport( ERROR, ( errcode( ERRCODE_INVALID_BINARY_REPRESENTATION ), errmsg( "Unexpected text to binary conversion occured" ) ) );
    return {};
  }
}

} // namespace

extern "C"
{
#include <utils/hashutils.h>

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

  Datum operation_in( PG_FUNCTION_ARGS )
  {
    const char* t            = PG_GETARG_CSTRING( 0 );
    std::vector< char > data = json_to_op( t ); // Get parsed operation in raw bytes

    PG_RETURN_HIVE_OPERATION( make_operation( data.data(), data.size() ) );
  }

  Datum operation_out( PG_FUNCTION_ARGS )
  {
    _operation* op       = PG_GETARG_HIVE_OPERATION_PP( 0 );
    uint32 data_length   = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    std::string op_str = op_to_json( raw_data, data_length ); // Get json from raw bytes

    uint32 op_ccp_size = op_str.size() + 1;
    char* op_ccp       = (char*) palloc( op_ccp_size ); // allocate space for postgres cstring

    const char* cstring_out = (const char*) memcpy( op_ccp, op_str.c_str(), op_ccp_size ); // copy json content from std::string to postgres cstring

    PG_RETURN_CSTRING( cstring_out );
  }

  Datum operation_bin_in_internal( PG_FUNCTION_ARGS )
  {
    StringInfo buf = (StringInfo) PG_GETARG_POINTER( 0 ); // Should contain raw bytes

    // data and length should be eqeual to VARDATA_ANY and VARSIZE_ANY returned from the operation_bin_out
    PG_RETURN_HIVE_OPERATION( make_operation( buf->data, buf->len - 1 /* skip trailing null terminating byte */ ) );
  }

  Datum operation_bin_in( PG_FUNCTION_ARGS )
  { // Same as operation_bin_in_internal, but accepts bytea instead of internal
    bytea* data          = PG_GETARG_BYTEA_PP( 0 );
    uint32 data_length   = VARSIZE_ANY_EXHDR( data );
    const char* raw_data = VARDATA_ANY( data );

    _operation* op = make_operation( raw_data, data_length );

    PG_RETURN_HIVE_OPERATION( op );
  }

  Datum operation_bin_out( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );

    bytea* data = (bytea*) palloc( VARSIZE_ANY_EXHDR( op ) + VARHDRSZ );
    SET_VARSIZE( data, VARSIZE_ANY_EXHDR( op ) + VARHDRSZ );
    memcpy( VARDATA( data ), VARDATA_ANY( op ), VARSIZE_ANY_EXHDR( op ) );

    // Just postgres allocate and copy from the raw operation data
    PG_RETURN_BYTEA_P( data );
  }

  Datum operation_eq( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) == 0 );
  }

  Datum operation_ne( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) != 0 );
  }

  Datum operation_gt( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) > 0 );
  }

  Datum operation_ge( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) >= 0 );
  }

  Datum operation_lt( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) < 0 );
  }

  Datum operation_le( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_BOOL( operation_cmp_impl( lhs, rhs ) <= 0 );
  }

  Datum operation_cmp( PG_FUNCTION_ARGS )
  {
    _operation* lhs = PG_GETARG_HIVE_OPERATION_PP( 0 );
    _operation* rhs = PG_GETARG_HIVE_OPERATION_PP( 1 );

    PG_RETURN_INT32( operation_cmp_impl( lhs, rhs ) );
  }
}
