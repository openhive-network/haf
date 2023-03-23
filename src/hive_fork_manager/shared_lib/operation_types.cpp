#include "operation_base.hpp"

#include <fc/io/raw.hpp>
#include <fc/crypto/hex.hpp>

#include <algorithm>

extern "C" {
#include "funcapi.h"
#include <utils/syscache.h>
#include <catalog/pg_type_d.h>
#include <catalog/pg_namespace_d.h>
#include <extension/hstore/hstore.h>
}

namespace {

Datum beneficiary_route_types_to_sql_array(const std::vector<hive::protocol::beneficiary_route_type>& beneficiaries);
Datum asset_to_sql_tuple(const hive::protocol::asset& asset);
Datum comment_options_extensions_to_sql_tuple(const hive::protocol::comment_options_extensions_type& extensions);
Datum extensions_type_to_sql_array(const hive::protocol::extensions_type& extensions);
Datum props_to_hstore(const fc::flat_map<std::string, std::vector<char>>& props);

// TODO: copied from operation_base.cpp
hive::protocol::operation raw_to_operation( const char* raw_data, uint32 data_length )
{
  if( !data_length )
    return {};

  return fc::raw::unpack_from_char_array< hive::protocol::operation >( raw_data, static_cast< uint32_t >( data_length ) );
}

Datum to_datum(bool value)
{
  return BoolGetDatum(value);
}
Datum to_datum(uint16_t value)
{
  return Int32GetDatum(value);
}
Datum to_datum(int16_t value)
{
  return UInt32GetDatum(value);
}
Datum to_datum(const std::string& value)
{
  return CStringGetTextDatum(value.c_str());
}
Datum to_datum(const std::vector<hive::protocol::beneficiary_route_type>& value)
{
  return beneficiary_route_types_to_sql_array(value);
}
Datum to_datum(const fc::flat_map<std::string, std::vector<char>>& value)
{
  return props_to_hstore(value);
}
Datum to_datum(const hive::protocol::account_name_type& value)
{
  return CStringGetTextDatum(static_cast<std::string>(value).c_str());
}
Datum to_datum(const hive::protocol::json_string& value)
{
  return DirectFunctionCall1(jsonb_in, CStringGetDatum(static_cast<std::string>(value).c_str()));
}
Datum to_datum(const hive::protocol::asset& value)
{
  return asset_to_sql_tuple(value);
}
Datum to_datum(const hive::protocol::comment_options_extensions_type& value)
{
  return comment_options_extensions_to_sql_tuple(value);
}
Datum to_datum(const hive::protocol::extensions_type& value)
{
  return extensions_type_to_sql_array(value);
}

template<typename T>
struct members_to_sql_tuple_visitor {
    members_to_sql_tuple_visitor(const T& obj, Datum* values) : obj(obj), values(values)
    {}

    template<typename Member, class Class, Member (Class::*member)>
    void operator()(const char*) const
    {
      values[i++] = to_datum(obj.*member);
    }

  private:
    const T& obj;
    mutable Datum* values;
    mutable size_t i = 0;
};

Datum comment_operation_to_sql_tuple(const hive::protocol::comment_operation& comment, FunctionCallInfo fcinfo)
{
  TupleDesc desc;
  TypeFuncClass cls = get_call_result_type(fcinfo, nullptr, &desc);
  if (cls != TYPEFUNC_COMPOSITE)
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "function returning record called in context that cannot accept type record." ) ) );
  }
  BlessTupleDesc(desc);
  Datum values[fc::reflector<hive::protocol::comment_operation>::total_member_count];
  fc::reflector<hive::protocol::comment_operation>::visit(members_to_sql_tuple_visitor(comment, values));
  bool nulls[fc::reflector<hive::protocol::comment_operation>::total_member_count] = {};
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

Datum beneficiary_route_type_to_sql_tuple(const hive::protocol::beneficiary_route_type& beneficiary)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.beneficiary_route_type");
  BlessTupleDesc(desc);
  Datum values[fc::reflector<hive::protocol::beneficiary_route_type>::total_member_count];
  fc::reflector<hive::protocol::beneficiary_route_type>::visit(members_to_sql_tuple_visitor(beneficiary, values));
  bool nulls[fc::reflector<hive::protocol::beneficiary_route_type>::total_member_count] = {};
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum beneficiary_route_types_to_sql_array(const std::vector<hive::protocol::beneficiary_route_type>& beneficiaries)
{
  Oid hiveOid = GetSysCacheOid1(NAMESPACENAME, Anum_pg_namespace_oid, CStringGetDatum("hive"));
  Oid elementOid = GetSysCacheOid2(TYPENAMENSP, Anum_pg_type_oid, CStringGetDatum("beneficiary_route_type"), ObjectIdGetDatum(hiveOid));

  if (!OidIsValid(elementOid))
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "could not determine data type of input" ) ) );
  }

  int16 typlen;
  bool  typbyval;
  char  typalign;

  // get required info about the element type
  get_typlenbyvalalign(elementOid, &typlen, &typbyval, &typalign);

  const auto elementCount = beneficiaries.size();
  std::vector<Datum> elements;
  elements.reserve(elementCount);
  std::transform(std::begin(beneficiaries), std::end(beneficiaries), std::begin(elements), beneficiary_route_type_to_sql_tuple);

  ArrayType* result = construct_array(elements.data(), elementCount, elementOid, typlen, typbyval, typalign);

  PG_RETURN_ARRAYTYPE_P(result);
}

Datum comment_payout_beneficiaries_to_sql_tuple(const hive::protocol::comment_payout_beneficiaries& payout_beneficiaries)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.comment_payout_beneficiaries");
  BlessTupleDesc(desc);
  Datum values[fc::reflector<hive::protocol::comment_payout_beneficiaries>::total_member_count];
  fc::reflector<hive::protocol::comment_payout_beneficiaries>::visit(members_to_sql_tuple_visitor(payout_beneficiaries, values));
  bool nulls[fc::reflector<hive::protocol::comment_payout_beneficiaries>::total_member_count] = {};
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
  Datum values[fc::reflector<hive::protocol::comment_options_operation>::total_member_count];
  fc::reflector<hive::protocol::comment_options_operation>::visit(members_to_sql_tuple_visitor(options, values));
  bool nulls[fc::reflector<hive::protocol::comment_options_operation>::total_member_count] = {};
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum vote_operation_to_sql_tuple(const hive::protocol::vote_operation& vote, FunctionCallInfo fcinfo)
{
  TupleDesc desc;
  TypeFuncClass cls = get_call_result_type(fcinfo, nullptr, &desc);
  if (cls != TYPEFUNC_COMPOSITE)
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "function returning record called in context that cannot accept type record." ) ) );
  }
  BlessTupleDesc(desc);
  Datum values[fc::reflector<hive::protocol::vote_operation>::total_member_count];
  fc::reflector<hive::protocol::vote_operation>::visit(members_to_sql_tuple_visitor(vote, values));
  bool nulls[fc::reflector<hive::protocol::vote_operation>::total_member_count] = {};
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum extensions_type_to_sql_array(const hive::protocol::extensions_type& extensions)
{
  Oid hiveOid = GetSysCacheOid1(NAMESPACENAME, Anum_pg_namespace_oid, CStringGetDatum("hive"));
  Oid elementOid = GetSysCacheOid2(TYPENAMENSP, Anum_pg_type_oid, CStringGetDatum("hive_future_extensions"), ObjectIdGetDatum(hiveOid));

  if (!OidIsValid(elementOid))
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "could not determine data type of input" ) ) );
  }

  int16 typlen;
  bool  typbyval;
  char  typalign;

  // get required info about the element type
  get_typlenbyvalalign(elementOid, &typlen, &typbyval, &typalign);

  const auto elementCount = 0;
  std::vector<Datum> elements;
  elements.reserve(elementCount);
  // TODO: std::transform(std::begin(extensions), std::end(extensions), std::begin(elements), future_extensions_to_sql_tuple);

  ArrayType* result = construct_array(elements.data(), elementCount, elementOid, typlen, typbyval, typalign);

  PG_RETURN_ARRAYTYPE_P(result);
}

Pairs prop_to_hstore_pair(const std::pair<std::string, std::vector<char>>& prop)
{
  const std::string& key = prop.first;
  const std::vector<char>& value = prop.second;
  const auto encodedValue = fc::to_hex(value);

  Pairs p;
  p.key = VARDATA(CStringGetTextDatum(key.c_str()));
  p.val = VARDATA(CStringGetTextDatum(encodedValue.c_str())),
  p.keylen = key.size();
  p.vallen = encodedValue.size();
  p.isnull = false;
  p.needfree = false;
  return p;
}

Datum props_to_hstore(const fc::flat_map<std::string, std::vector<char>>& props)
{
  auto element_count = props.size();

  Pairs* pairs = (Pairs*)palloc(element_count * sizeof(Pairs));
  std::transform(std::begin(props), std::end(props), pairs, prop_to_hstore_pair);

  int32 buflen;
  void* ptr;
  // TODO: memoise loading function pointers
  auto* hstoreUniquePairs = (int (*)(Pairs *, int32, int32*))load_external_function("hstore.so", "hstoreUniquePairs", true, &ptr);
  element_count = hstoreUniquePairs(pairs, element_count, &buflen);
  auto* hstorePairs = (HStore* (*)(Pairs*, int32, int32))load_external_function("hstore.so", "hstorePairs", true, &ptr);
  HStore* out = hstorePairs(pairs, element_count, buflen);
  PG_RETURN_POINTER(out);
}

Datum witness_set_properties_operation_to_sql_tuple(const hive::protocol::witness_set_properties_operation& properties, FunctionCallInfo fcinfo)
{
  TupleDesc desc;
  TypeFuncClass cls = get_call_result_type(fcinfo, nullptr, &desc);
  if (cls != TYPEFUNC_COMPOSITE)
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "function returning record called in context that cannot accept type record." ) ) );
  }
  BlessTupleDesc(desc);
  Datum values[fc::reflector<hive::protocol::witness_set_properties_operation>::total_member_count];
  fc::reflector<hive::protocol::witness_set_properties_operation>::visit(members_to_sql_tuple_visitor(properties, values));
  bool nulls[fc::reflector<hive::protocol::witness_set_properties_operation>::total_member_count] = {};
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

  PG_FUNCTION_INFO_V1( operation_to_vote_operation );
  Datum operation_to_vote_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    uint32 data_length = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    try
    {
      const hive::protocol::operation operation = raw_to_operation( raw_data, data_length );
      const hive::protocol::vote_operation options = operation.get<hive::protocol::vote_operation>();
      return vote_operation_to_sql_tuple(options, fcinfo);
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
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "Could not convert operation to vote_operation" ) ) );
    }
  }

  PG_FUNCTION_INFO_V1( operation_to_witness_set_properties_operation );
  Datum operation_to_witness_set_properties_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    uint32 data_length = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    try
    {
      const hive::protocol::operation operation = raw_to_operation( raw_data, data_length );
      const hive::protocol::witness_set_properties_operation options = operation.get<hive::protocol::witness_set_properties_operation>();
      return witness_set_properties_operation_to_sql_tuple(options, fcinfo);
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
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "Could not convert operation to witness_set_properties_operation" ) ) );
    }
  }
}
