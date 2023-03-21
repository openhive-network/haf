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

Datum asset_to_sql_tuple(const hive::protocol::asset& asset)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.asset");
  BlessTupleDesc(desc);
  Datum values[] = {
    Int64GetDatum(asset.amount.value),
    Int16GetDatum(asset.symbol.decimals()),
    CStringGetTextDatum(asset.symbol.to_nai_string().c_str()),
  };
  bool nulls[] = {
    false,
    false,
    false,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum comment_payout_beneficiaries_to_sql_tuple(const hive::protocol::comment_payout_beneficiaries& payout_beneficiaries)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.comment_payout_beneficiaries");
  BlessTupleDesc(desc);
  Datum values[] = {
    (Datum)0,
  };
  bool nulls[] = {
    true,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum comment_options_extensions_to_sql_tuple(const hive::protocol::comment_options_extensions_type& extensions)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.comment_options_extensions_type");
  BlessTupleDesc(desc);
  Datum values[] = {
    (Datum)0, // comment_payout_beneficiaries
    (Datum)0, // allowed_vote_assets
  };
  bool nulls[] = {
    true,
    true,
  };
  struct extensions_visitor
  {
    using result_type = void;

    extensions_visitor(Datum* values, bool* nulls) : values(values), nulls(nulls)
    {}
    void operator()(const hive::protocol::comment_payout_beneficiaries& payout_beneficiaries)
    {
      values[0] = comment_payout_beneficiaries_to_sql_tuple(payout_beneficiaries);
      nulls[0] = false;
    }
#ifdef HIVE_ENABLE_SMT
    void operator()(const hive::protocol::allowed_vote_assets& allowed_vote_assets)
    {
      // TODO: values[1] = ...
      // TODO: nulls[1] = false;
    }
#endif /// HIVE_ENABLE_SMT
  private:
    Datum* values;
    bool* nulls;
  };
  extensions_visitor v(values, nulls);
  for (const auto& extension : extensions)
  {
    extension.visit(v);
  }
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum comment_options_operation_to_sql_tuple(const hive::protocol::comment_options_operation& options, FunctionCallInfo fcinfo)
{
  TupleDesc desc;
  TypeFuncClass cls = get_call_result_type(fcinfo, nullptr, &desc);
  if (cls != TYPEFUNC_COMPOSITE)
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "function returning record called in context that cannot accept type record." ) ) );
  }
  BlessTupleDesc(desc);
  Datum values[] = {
    CStringGetTextDatum(static_cast<std::string>(options.author).c_str()),
    CStringGetTextDatum(options.permlink.c_str()),
    asset_to_sql_tuple(options.max_accepted_payout),
    UInt16GetDatum(options.percent_hbd),
    BoolGetDatum(options.allow_votes),
    BoolGetDatum(options.allow_curation_rewards),
    comment_options_extensions_to_sql_tuple(options.extensions),
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

  PG_FUNCTION_INFO_V1( operation_to_comment_options_operation );
  Datum operation_to_comment_options_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    uint32 data_length = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    try
    {
      const hive::protocol::operation operation = raw_to_operation( raw_data, data_length );
      const hive::protocol::comment_options_operation options = operation.get<hive::protocol::comment_options_operation>();
      return comment_options_operation_to_sql_tuple(options, fcinfo);
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
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "Could not convert operation to comment_options_operation" ) ) );
    }
  }
}
