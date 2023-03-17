#include "operation_base.hpp"

#include "funcapi.h"

#include <fc/io/raw.hpp>

namespace {

// TODO: copied from operation_base.cpp
hive::protocol::operation raw_to_operation( const char* raw_data, uint32 data_length )
{
  if( !data_length )
    return {};

  return fc::raw::unpack_from_char_array< hive::protocol::operation >( raw_data, static_cast< uint32_t >( data_length ) );
}

Datum comment_operation_to_sql_tuple(const hive::protocol::comment_operation& comment, FunctionCallInfo fcinfo)
{
  TupleDesc desc;
  TypeFuncClass cls = get_call_result_type(fcinfo, nullptr, &desc);
  if (cls != TYPEFUNC_COMPOSITE)
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "function returning record called in context that cannot accept type record." ) ) );
  }
  BlessTupleDesc(desc);
  Datum values[] = {
    CStringGetTextDatum(static_cast<std::string>(comment.parent_author).c_str()),
    CStringGetTextDatum(comment.parent_permlink.c_str()),
    CStringGetTextDatum(static_cast<std::string>(comment.author).c_str()),
    CStringGetTextDatum(comment.permlink.c_str()),
    CStringGetTextDatum(comment.title.c_str()),
    CStringGetTextDatum(comment.body.c_str()),
    DirectFunctionCall1(jsonb_in, CStringGetDatum(static_cast<std::string>(comment.json_metadata).c_str())),
  };
  bool nulls[] = {
    false,
    false,
    false,
    false,
    false,
    false,
    false,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

}

extern "C"
{
  PG_FUNCTION_INFO_V1( operation_to_comment_operation );
  Datum operation_to_comment_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    uint32 data_length = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    try
    {
      const hive::protocol::operation operation = raw_to_operation( raw_data, data_length );
      const hive::protocol::comment_operation comment = operation.get<hive::protocol::comment_operation>();
      return comment_operation_to_sql_tuple(comment, fcinfo);
    }
    catch( const fc::exception& e )
    {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "%s", e.to_string().c_str() ) ) );
    }
    catch( const std::exception& e )
    {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "%s", e.what() ) ) );
    }
    catch( ... )
    {
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "Could not convert operation to comment_operation" ) ) );
    }

  }
}
