#include "operation_base.hpp"

#include <fc/io/raw.hpp>
#include <fc/crypto/hex.hpp>

#include <algorithm>
#include <iterator>

extern "C" {
#include "funcapi.h"
#include <utils/syscache.h>
#include <catalog/pg_type_d.h>
#include <catalog/pg_namespace_d.h>
#include <extension/hstore/hstore.h>
}

namespace {

Datum props_to_hstore(const fc::flat_map<std::string, std::vector<char>>& props);
Datum account_authority_map_to_hstore(const fc::flat_map<hive::protocol::account_name_type, hive::protocol::weight_type>& auth);
Datum key_authority_map_to_hstore(const fc::flat_map<hive::protocol::public_key_type, hive::protocol::weight_type>& auth);

template<typename T>
Datum to_sql_tuple(const T& value);
Datum to_sql_tuple(const hive::protocol::asset& asset);
Datum to_sql_tuple(const hive::protocol::comment_options_extensions_type& extensions);
Datum to_sql_tuple(const hive::protocol::future_extensions& extensions);

template<typename Iter>
Datum to_sql_array(Iter first, Iter last);

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
Datum to_datum(uint32_t value)
{
  return Int64GetDatum(value);
}
Datum to_datum(const std::string& value)
{
  return CStringGetTextDatum(value.c_str());
}
Datum to_datum(const std::vector<char>& value)
{
  const auto size = value.size();
  bytea* bytes = (bytea*)palloc(VARHDRSZ + size);
  std::copy(std::begin(value), std::end(value), VARDATA(bytes));
  SET_VARSIZE(bytes, VARHDRSZ + size);
  PG_RETURN_BYTEA_P(bytes);
}
template<typename T>
Datum to_datum(const std::vector<T>& value)
{
  return to_sql_array(std::begin(value), std::end(value));
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
  return to_sql_tuple(value);
}
Datum to_datum(const hive::protocol::comment_options_extensions_type& value)
{
  return to_sql_tuple(value);
}
Datum to_datum(const hive::protocol::authority& value)
{
  return to_sql_tuple(value);
}
Datum to_datum(const hive::protocol::authority::account_authority_map& value)
{
  return account_authority_map_to_hstore(value);
}
Datum to_datum(const hive::protocol::authority::key_authority_map& value)
{
  return key_authority_map_to_hstore(value);
}
Datum to_datum(const hive::protocol::extensions_type& value)
{
  return to_sql_array(std::begin(value), std::end(value));
}
Datum to_datum(const hive::protocol::public_key_type& value)
{
  return CStringGetTextDatum(static_cast<std::string>(value).c_str());
}
template<typename T>
std::optional<Datum> to_datum(const fc::optional<T>& value)
{
  if (value.valid()) return {to_datum(value.value())};
  else return std::nullopt; // NULL
}
template<typename T>
Datum to_datum(const fc::flat_set<T>& value)
{
  return to_sql_array(std::begin(value), std::end(value));
}

template<typename T>
struct members_to_sql_tuple_visitor {
    members_to_sql_tuple_visitor(const T& obj, Datum* values, bool* nulls) : obj(obj), values(values), nulls(nulls)
    {}

    template<typename Member, class Class, Member (Class::*member)>
    void operator()(const char*) const
    {
      const std::optional<Datum> datum = to_datum(obj.*member);
      if (datum.has_value())
      {
        values[i] = datum.value();
      }
      else
      {
        values[i] = (Datum)0;
        nulls[i] = true;
      }
      i++;
    }

  private:
    const T& obj;
    mutable Datum* values;
    mutable bool* nulls;
    mutable size_t i = 0;
};

template<typename T>
Datum to_sql_tuple(const T& value)
{
  const std::string type_name = fc::trim_typename_namespace(fc::get_typename<T>::name());
  TupleDesc desc = RelationNameGetTupleDesc(("hive." + type_name).c_str());
  BlessTupleDesc(desc);
  Datum values[fc::reflector<T>::total_member_count];
  bool nulls[fc::reflector<T>::total_member_count] = {};
  fc::reflector<T>::visit(members_to_sql_tuple_visitor(value, values, nulls));
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_sql_tuple(const hive::protocol::asset& asset)
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

template<typename T>
Datum to_sql_tuple(const hive::protocol::fixed_string_impl<T>& string)
{
  return CStringGetTextDatum(static_cast<std::string>(string).c_str());
}

Datum to_sql_tuple(const hive::protocol::future_extensions& extensions)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.void_t");
  BlessTupleDesc(desc);
  Datum values[] = {};
  bool nulls[] = {};
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

template<typename T>
std::string sql_typename_from_protocol_type()
{
  return fc::trim_typename_namespace(fc::get_typename<T>::name());
}
template<>
std::string sql_typename_from_protocol_type<hive::protocol::future_extensions>()
{
  return "void_t";
}
template<>
std::string sql_typename_from_protocol_type<hive::protocol::account_name_type>()
{
  return "account_name_type";
}

template<typename Iter>
Datum to_sql_array(Iter first, Iter last)
{
  using value_type = typename std::iterator_traits<Iter>::value_type;
  const std::string type_name = sql_typename_from_protocol_type<value_type>();
  Oid hiveOid = GetSysCacheOid1(NAMESPACENAME, Anum_pg_namespace_oid, CStringGetDatum("hive"));
  Oid elementOid = GetSysCacheOid2(TYPENAMENSP, Anum_pg_type_oid, CStringGetDatum(type_name.c_str()), ObjectIdGetDatum(hiveOid));

  if (!OidIsValid(elementOid))
  {
    ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "could not determine data type of input" ) ) );
  }

  int16 typlen;
  bool  typbyval;
  char  typalign;

  // get required info about the element type
  get_typlenbyvalalign(elementOid, &typlen, &typbyval, &typalign);

  const auto elementCount = std::distance(first, last);
  std::vector<Datum> elements;
  elements.reserve(elementCount);
  std::transform(first, last, std::begin(elements), [](const auto& v){return to_sql_tuple(v);});

  ArrayType* result = construct_array(elements.data(), elementCount, elementOid, typlen, typbyval, typalign);
  PG_RETURN_ARRAYTYPE_P(result);
}

Datum to_sql_tuple(const hive::protocol::comment_options_extensions_type& extensions)
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
      values[0] = to_sql_tuple(payout_beneficiaries);
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

Pairs account_authority_to_hstore_pair(const std::pair<hive::protocol::account_name_type, hive::protocol::weight_type>& auth)
{
  const hive::protocol::account_name_type& key = auth.first;
  hive::protocol::weight_type value = auth.second;
  const std::string stringKey = static_cast<std::string>(key);
  const std::string stringValue = std::to_string(value);

  Pairs p;
  p.key = VARDATA(CStringGetTextDatum(stringKey.c_str()));
  p.val = VARDATA(CStringGetTextDatum(stringValue.c_str())),
  p.keylen = stringKey.size();
  p.vallen = stringValue.size();
  p.isnull = false;
  p.needfree = false;
  return p;
}

Datum account_authority_map_to_hstore(const fc::flat_map<hive::protocol::account_name_type, hive::protocol::weight_type>& auth)
{
  auto element_count = auth.size();

  Pairs* pairs = (Pairs*)palloc(element_count * sizeof(Pairs));
  std::transform(std::begin(auth), std::end(auth), pairs, account_authority_to_hstore_pair);

  int32 buflen;
  void* ptr;
  // TODO: memoise loading function pointers
  auto* hstoreUniquePairs = (int (*)(Pairs *, int32, int32*))load_external_function("hstore.so", "hstoreUniquePairs", true, &ptr);
  element_count = hstoreUniquePairs(pairs, element_count, &buflen);
  auto* hstorePairs = (HStore* (*)(Pairs*, int32, int32))load_external_function("hstore.so", "hstorePairs", true, &ptr);
  HStore* out = hstorePairs(pairs, element_count, buflen);
  PG_RETURN_POINTER(out);
}

Pairs key_authority_to_hstore_pair(const std::pair<hive::protocol::public_key_type, hive::protocol::weight_type>& auth)
{
  const hive::protocol::public_key_type& key = auth.first;
  hive::protocol::weight_type value = auth.second;
  const std::string stringKey = static_cast<std::string>(key);
  const std::string stringValue = std::to_string(value);

  Pairs p;
  p.key = VARDATA(CStringGetTextDatum(stringKey.c_str()));
  p.val = VARDATA(CStringGetTextDatum(stringValue.c_str())),
  p.keylen = stringKey.size();
  p.vallen = stringValue.size();
  p.isnull = false;
  p.needfree = false;
  return p;
}

Datum key_authority_map_to_hstore(const fc::flat_map<hive::protocol::public_key_type, hive::protocol::weight_type>& auth)
{
  auto element_count = auth.size();

  Pairs* pairs = (Pairs*)palloc(element_count * sizeof(Pairs));
  std::transform(std::begin(auth), std::end(auth), pairs, key_authority_to_hstore_pair);

  int32 buflen;
  void* ptr;
  // TODO: memoise loading function pointers
  auto* hstoreUniquePairs = (int (*)(Pairs *, int32, int32*))load_external_function("hstore.so", "hstoreUniquePairs", true, &ptr);
  element_count = hstoreUniquePairs(pairs, element_count, &buflen);
  auto* hstorePairs = (HStore* (*)(Pairs*, int32, int32))load_external_function("hstore.so", "hstorePairs", true, &ptr);
  HStore* out = hstorePairs(pairs, element_count, buflen);
  PG_RETURN_POINTER(out);
}

template<typename T>
Datum operation_to(_operation* op)
{
    uint32 data_length = VARSIZE_ANY_EXHDR( op );
    const char* raw_data = VARDATA_ANY( op );

    try
    {
      const hive::protocol::operation operation = raw_to_operation( raw_data, data_length );
      const T& actual_op = operation.get<T>();
      return to_sql_tuple(actual_op);
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
      const std::string type_name = fc::trim_typename_namespace(fc::get_typename<T>::name());
      ereport( ERROR, ( errcode( ERRCODE_DATA_EXCEPTION ), errmsg( "Could not convert operation to %s", type_name.c_str() ) ) );
    }
}

}

extern "C"
{
  PG_FUNCTION_INFO_V1( operation_to_comment_operation );
  Datum operation_to_comment_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::comment_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_comment_options_operation );
  Datum operation_to_comment_options_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::comment_options_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_vote_operation );
  Datum operation_to_vote_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::vote_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_witness_set_properties_operation );
  Datum operation_to_witness_set_properties_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::witness_set_properties_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_account_create_operation );
  Datum operation_to_account_create_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::account_create_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_account_create_with_delegation_operation );
  Datum operation_to_account_create_with_delegation_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::account_create_with_delegation_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_account_update2_operation );
  Datum operation_to_account_update2_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::account_update2_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_account_update_operation );
  Datum operation_to_account_update_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::account_update_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_account_witness_proxy_operation );
  Datum operation_to_account_witness_proxy_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::account_witness_proxy_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_account_witness_vote_operation );
  Datum operation_to_account_witness_vote_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::account_witness_vote_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_cancel_transfer_from_savings_operation );
  Datum operation_to_cancel_transfer_from_savings_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::cancel_transfer_from_savings_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_change_recovery_account_operation );
  Datum operation_to_change_recovery_account_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::change_recovery_account_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_claim_account_operation );
  Datum operation_to_claim_account_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::claim_account_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_claim_reward_balance_operation );
  Datum operation_to_claim_reward_balance_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::claim_reward_balance_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_collateralized_convert_operation );
  Datum operation_to_collateralized_convert_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::collateralized_convert_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_convert_operation );
  Datum operation_to_convert_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::convert_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_create_claimed_account_operation );
  Datum operation_to_create_claimed_account_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::create_claimed_account_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_custom_binary_operation );
  Datum operation_to_custom_binary_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::custom_binary_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_custom_json_operation );
  Datum operation_to_custom_json_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::custom_json_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_custom_operation );
  Datum operation_to_custom_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::custom_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_decline_voting_rights_operation );
  Datum operation_to_decline_voting_rights_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::decline_voting_rights_operation>(op);
  }
}
