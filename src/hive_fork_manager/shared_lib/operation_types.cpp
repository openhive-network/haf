#include "operation_base.hpp"

#include <psql_utils/pg_cxx.hpp>

#include "extract_set_witness_properties.hpp"
#include "operation_conversion.hpp"
#include "to_jsonb.hpp"

#include <fc/io/raw.hpp>
#include <fc/crypto/hex.hpp>

#include <algorithm>
#include <iterator>

extern "C" {
#include "funcapi.h"
#include <utils/syscache.h>
#include <catalog/pg_type_d.h>
#include <catalog/pg_namespace_d.h>
}

namespace {

Datum to_datum(bool value);
Datum to_datum(uint8_t value);
Datum to_datum(uint16_t value);
Datum to_datum(int16_t value);
Datum to_datum(uint32_t value);
Datum to_datum(uint64_t value);
Datum to_datum(int64_t value);
Datum to_datum(const std::string& value);
Datum to_datum(const std::vector<char>& value);
template<typename T>
Datum to_datum(const std::vector<T>& value);
Datum to_datum(const fc::flat_map<std::string, std::string>& value);
Datum to_datum(const hive::protocol::account_name_type& value);
std::optional<Datum> to_datum(const hive::protocol::json_string& value);
Datum to_datum(const hive::protocol::authority::account_authority_map& value);
Datum to_datum(const hive::protocol::authority::key_authority_map& value);
Datum to_datum(const hive::protocol::extensions_type& value);
Datum to_datum(const hive::protocol::public_key_type& value);
Datum to_datum(const fc::ripemd160& value);
Datum to_datum(const fc::sha256& value);
Datum to_datum(const fc::time_point_sec& value);
template<typename T>
Datum to_datum(const fc::flat_set<T>& value);
template<typename T>
Datum to_datum(const flat_set_ex<T>& value);
Datum to_datum(const hive::protocol::legacy_hive_asset& value);
template<typename T, size_t N>
Datum to_datum(const fc::array<T, N>& value);
template<typename T>
Datum to_datum(const T& value);
Datum to_datum(const hive::protocol::witness_set_properties_operation& value);
Datum to_datum(const std::pair<std::string, std::string>& value);
Datum to_datum(const std::pair<hive::protocol::account_name_type, hive::protocol::weight_type>& value);
Datum to_datum(const std::pair<hive::protocol::public_key_type, hive::protocol::weight_type>& value);
Datum to_datum(const hive::protocol::asset& asset);
Datum to_datum(const hive::protocol::price& price);
template<typename T>
Datum to_datum(const hive::protocol::fixed_string_impl<T>& string);
Datum to_datum(const hive::protocol::future_extensions& extensions);
Datum to_datum(const hive::protocol::recurrent_transfer_pair_id& id);
Datum to_datum(const hive::protocol::recurrent_transfer_extensions_type& extensions);
Datum to_datum(const hive::protocol::comment_options_extensions_type& extensions);
Datum to_datum(const hive::protocol::pow2_work& work);
Datum to_datum(const hive::protocol::update_proposal_extensions_type& extensions);

template<typename Iter>
Datum make_sql_array(Iter first, Iter last, const fc::string& namespace_name, const fc::string& type_name);

template<typename Iter>
Datum to_sql_array(Iter first, Iter last);

Datum to_datum(bool value)
{
  return BoolGetDatum(value);
}
Datum to_datum(uint8_t value)
{
  return UInt16GetDatum(value);
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
Datum to_datum(uint64_t value)
{
  return PsqlTools::PsqlUtils::cxx_direct_call_pg(numeric_in, CStringGetDatum(std::to_string(value).c_str()), ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
}
Datum to_datum(int64_t value)
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
Datum to_datum(const fc::flat_map<std::string, std::string>& value)
{
  return to_sql_array(std::begin(value), std::end(value));
}
Datum to_datum(const hive::protocol::account_name_type& value)
{
  return CStringGetTextDatum(static_cast<std::string>(value).c_str());
}
std::optional<Datum> to_datum(const hive::protocol::json_string& value)
{
  if (value.empty()) return {};
  else return to_datum(static_cast<std::string>(value));
}
Datum to_datum(const hive::protocol::authority::account_authority_map& value)
{
  return to_sql_array(std::begin(value), std::end(value));
}
Datum to_datum(const hive::protocol::authority::key_authority_map& value)
{
  return to_sql_array(std::begin(value), std::end(value));
}
Datum to_datum(const hive::protocol::extensions_type& value)
{
  return to_sql_array(std::begin(value), std::end(value));
}
Datum to_datum(const hive::protocol::public_key_type& value)
{
  return CStringGetTextDatum(static_cast<std::string>(value).c_str());
}
Datum to_datum(const fc::ripemd160& value)
{
  return CStringGetTextDatum(static_cast<std::string>(value).c_str());
}
Datum to_datum(const fc::sha256& value)
{
  return CStringGetTextDatum(static_cast<std::string>(value).c_str());
}
Datum to_datum(const fc::time_point_sec& value)
{
  const auto str = static_cast<fc::string>(value);
  return PsqlTools::PsqlUtils::cxx_direct_call_pg(timestamp_in, CStringGetDatum(str.c_str()), ObjectIdGetDatum(InvalidOid), Int32GetDatum(-1));
}
template<typename T>
std::optional<Datum> to_datum(const fc::safe<T>& value)
{
  return to_datum(value.value);
}
template<typename T>
std::optional<Datum> to_datum(const fc::optional<T>& value)
{
  if (value.valid()) return {to_datum(value.value())};
  else return std::nullopt;
}
template<typename T>
Datum to_datum(const fc::flat_set<T>& value)
{
  return to_sql_array(std::begin(value), std::end(value));
}
template<typename T>
Datum to_datum(const flat_set_ex<T>& value)
{
  return to_datum(static_cast<const fc::flat_set<T>&>(value));
}
Datum to_datum(const hive::protocol::legacy_hive_asset& value)
{
  return to_datum(value.to_asset<false>());
}
template<typename T, size_t N>
Datum to_datum(const fc::array<T, N>& value)
{
  bytea* bytes = (bytea*)palloc(VARHDRSZ + N);
  std::copy(std::begin(value), std::end(value), VARDATA(bytes));
  SET_VARSIZE(bytes, VARHDRSZ + N);
  PG_RETURN_BYTEA_P(bytes);
}
template<uint32_t _SYMBOL>
Datum to_datum(const hive::protocol::tiny_asset<_SYMBOL>& value)
{
  return to_datum(value.to_asset());
}

template<typename T>
struct members_to_datum_visitor {
    members_to_datum_visitor(const T& obj, Datum* values, bool* nulls) : obj(obj), values(values), nulls(nulls)
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
Datum to_datum(const T& value)
{
  const std::string type_name = fc::trim_typename_namespace(fc::get_typename<T>::name());
  TupleDesc desc = RelationNameGetTupleDesc(("hive." + type_name).c_str());
  BlessTupleDesc(desc);
  const auto member_count = fc::reflector<T>::total_member_count;
  FC_ASSERT(member_count == desc->natts, "Fatal: mismatch between member count and tuple size for ${t} type", ("t", type_name));
  Datum values[member_count];
  bool nulls[member_count] = {};
  fc::reflector<T>::visit(members_to_datum_visitor(value, values, nulls));
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const hive::protocol::witness_set_properties_operation& value)
{
  // Special processing for witness_set_properties_operation.props
  const std::string type_name = fc::trim_typename_namespace(fc::get_typename<hive::protocol::witness_set_properties_operation>::name());
  TupleDesc desc = RelationNameGetTupleDesc("hive.witness_set_properties_operation");
  BlessTupleDesc(desc);
  const auto member_count = fc::reflector<hive::protocol::witness_set_properties_operation>::total_member_count;
  FC_ASSERT(member_count == desc->natts, "Fatal: mismatch between member count and tuple size for ${t} type", ("t", type_name));
  FC_ASSERT(member_count == 3, "Fatal: member count mismatch in to_datum(witness_set_properties_operation)");
  fc::flat_map<fc::string, fc::string> output;
  // TODO: we convert props to flat_map just to convert it to array later.
  // This is wasteful, consider converting it in one step, but without duplicating logic of extract_set_witness_properties_from_flat_map.
  extract_set_witness_properties_from_flat_map(output, value.props);
  Datum values[member_count] = {
    to_datum(value.owner),
    to_datum(output),
    to_datum(value.extensions),
  };
  bool nulls[member_count] = {false, false, false};
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const std::pair<std::string, std::string>& value)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.witness_property");
  BlessTupleDesc(desc);
  Datum values[] = {
    CStringGetTextDatum(value.first.c_str()),
    CStringGetTextDatum(value.second.c_str()),
  };
  bool nulls[] = {
    false,
    false,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const std::pair<hive::protocol::account_name_type, hive::protocol::weight_type>& value)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.account_auth");
  BlessTupleDesc(desc);
  Datum values[] = {
    to_datum(value.first),
    to_datum(value.second),
  };
  bool nulls[] = {
    false,
    false,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const std::pair<hive::protocol::public_key_type, hive::protocol::weight_type>& value)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.key_auth");
  BlessTupleDesc(desc);
  Datum values[] = {
    to_datum(value.first),
    to_datum(value.second),
  };
  bool nulls[] = {
    false,
    false,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const hive::protocol::asset& asset)
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

Datum to_datum(const hive::protocol::price& price)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.price");
  BlessTupleDesc(desc);
  Datum values[] = {
    to_datum(price.base),
    to_datum(price.quote),
  };
  bool nulls[] = {
    false,
    false,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

template<typename T>
Datum to_datum(const hive::protocol::fixed_string_impl<T>& string)
{
  return CStringGetTextDatum(static_cast<std::string>(string).c_str());
}

Datum to_datum(const hive::protocol::future_extensions& extensions)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.void_t");
  BlessTupleDesc(desc);
  Datum values[] = {};
  bool nulls[] = {};
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const hive::protocol::recurrent_transfer_pair_id& id)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.recurrent_transfer_pair_id");
  BlessTupleDesc(desc);
  Datum values[] = {
      Int16GetDatum(id.pair_id),
  };
  bool nulls[] = {
    false,
  };
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const hive::protocol::recurrent_transfer_extensions_type& extensions)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.recurrent_transfer_extensions_type");
  BlessTupleDesc(desc);
  Datum values[] = {
    (Datum)0, // recurrent_transfer_pair_id
  };
  bool nulls[] = {
    true,
  };
  struct recurrent_transfer_extensions_visitor
  {
    using result_type = void;

    recurrent_transfer_extensions_visitor(Datum* values, bool* nulls) : values(values), nulls(nulls)
    {}
    void operator()(const hive::protocol::recurrent_transfer_pair_id& extension)
    {
      values[0] = to_datum(extension);
      nulls[0] = false;
    }
    void operator()(const hive::void_t&)
    {
      // do nothing
    }
  private:
    Datum* values;
    bool* nulls;
  };
  recurrent_transfer_extensions_visitor v(values, nulls);
  for (const auto& extension : extensions)
  {
    extension.visit(v);
  }
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

template<typename T>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type()
{
  return {"hive", fc::trim_typename_namespace(fc::get_typename<T>::name())};
}
template<>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type<hive::protocol::future_extensions>()
{
  return {"hive", "hive_future_extensions"};
}
template<>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type<hive::protocol::account_name_type>()
{
  return {"hive", "account_name_type"};
}
template<>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type<uint32_t>()
{
  return {"pg_catalog", "int8"};
}
template<>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type<int64_t>()
{
  return {"pg_catalog", "int8"};
}
template<>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type<std::pair<std::string, std::string>>()
{
  return {"hive", "witness_property"};
}
template<>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type<std::pair<hive::protocol::account_name_type, hive::protocol::weight_type>>()
{
  return {"hive", "account_auth"};
}
template<>
std::pair<std::string, std::string> sql_namespace_and_type_name_from_type<std::pair<hive::protocol::public_key_type, hive::protocol::weight_type>>()
{
  return {"hive", "key_auth"};
}

template <typename Iter>
Datum make_sql_array(Iter first, Iter last, const fc::string& namespace_name, const fc::string& type_name)
{
  static_assert(std::is_same_v<typename std::iterator_traits<Iter>::value_type, Datum>);
  Oid hiveOid = GetSysCacheOid1(NAMESPACENAME, Anum_pg_namespace_oid, CStringGetDatum(namespace_name.c_str()));
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

  ArrayType* result = construct_array(&*first, elementCount, elementOid, typlen, typbyval, typalign);
  PG_RETURN_ARRAYTYPE_P(result);
}

template<typename Iter>
Datum to_sql_array(Iter first, Iter last)
{
  using value_type = typename std::iterator_traits<Iter>::value_type;
  const auto [namespace_name, type_name] = sql_namespace_and_type_name_from_type<value_type>();

  const auto elementCount = std::distance(first, last);
  std::vector<Datum> elements;
  elements.resize(elementCount);
  std::transform(first, last, std::begin(elements), [](const auto& v){return to_datum(v);});

  return make_sql_array(std::begin(elements), std::end(elements), namespace_name, type_name);
}

Datum to_datum(const hive::protocol::comment_options_extensions_type& extensions)
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
      values[0] = to_datum(payout_beneficiaries);
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

Datum to_datum(const hive::protocol::pow2_work& work)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.pow2_work");
  BlessTupleDesc(desc);
  Datum values[] = {
    (Datum)0, // pow2
    (Datum)0, // equihash_pow
  };
  bool nulls[] = {
    true,
    true,
  };
  struct pow_visitor
  {
    using result_type = void;

    pow_visitor(Datum* values, bool* nulls) : values(values), nulls(nulls)
    {}
    void operator()(const hive::protocol::pow2& pow2)
    {
      values[0] = to_datum(pow2);
      nulls[0] = false;
    }
    void operator()(const hive::protocol::equihash_pow& pow)
    {
      values[1] = to_datum(pow);
      nulls[1] = false;
    }
  private:
    Datum* values;
    bool* nulls;
  };
  pow_visitor v(values, nulls);
  work.visit(v);
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
}

Datum to_datum(const hive::protocol::update_proposal_extensions_type& extensions)
{
  TupleDesc desc = RelationNameGetTupleDesc("hive.update_proposal_extensions_type");
  BlessTupleDesc(desc);
  Datum values[] = {
    (Datum)0, // update_proposal_end_date
  };
  bool nulls[] = {
    true,
  };
  struct update_proposal_extensions_visitor
  {
    using result_type = void;

    update_proposal_extensions_visitor(Datum* values, bool* nulls) : values(values), nulls(nulls)
    {}
    void operator()(const hive::protocol::update_proposal_end_date& new_date)
    {
      values[0] = to_datum(new_date);
      nulls[0] = false;
    }
    void operator()(const hive::void_t&)
    {
      // do nothing
    }
  private:
    Datum* values;
    bool* nulls;
  };
  update_proposal_extensions_visitor v(values, nulls);
  for (const auto& extension : extensions)
  {
    extension.visit(v);
  }
  HeapTuple tuple = heap_form_tuple(desc, values, nulls);
  PG_RETURN_DATUM(HeapTupleGetDatum(tuple));
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
      return to_datum(actual_op);
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

  PG_FUNCTION_INFO_V1( operation_to_delegate_vesting_shares_operation );
  Datum operation_to_delegate_vesting_shares_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::delegate_vesting_shares_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_delete_comment_operation );
  Datum operation_to_delete_comment_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::delete_comment_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_escrow_approve_operation );
  Datum operation_to_escrow_approve_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::escrow_approve_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_escrow_dispute_operation );
  Datum operation_to_escrow_dispute_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::escrow_dispute_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_escrow_release_operation );
  Datum operation_to_escrow_release_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::escrow_release_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_escrow_transfer_operation );
  Datum operation_to_escrow_transfer_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::escrow_transfer_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_feed_publish_operation );
  Datum operation_to_feed_publish_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::feed_publish_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_limit_order_cancel_operation );
  Datum operation_to_limit_order_cancel_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::limit_order_cancel_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_limit_order_create2_operation );
  Datum operation_to_limit_order_create2_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::limit_order_create2_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_limit_order_create_operation );
  Datum operation_to_limit_order_create_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::limit_order_create_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_pow2_operation );
  Datum operation_to_pow2_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::pow2_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_pow_operation );
  Datum operation_to_pow_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::pow_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_recover_account_operation );
  Datum operation_to_recover_account_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::recover_account_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_recurrent_transfer_operation );
  Datum operation_to_recurrent_transfer_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::recurrent_transfer_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_request_account_recovery_operation );
  Datum operation_to_request_account_recovery_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::request_account_recovery_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_reset_account_operation );
  Datum operation_to_reset_account_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::reset_account_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_set_reset_account_operation );
  Datum operation_to_set_reset_account_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::set_reset_account_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_set_withdraw_vesting_route_operation );
  Datum operation_to_set_withdraw_vesting_route_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::set_withdraw_vesting_route_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_transfer_from_savings_operation );
  Datum operation_to_transfer_from_savings_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::transfer_from_savings_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_transfer_operation );
  Datum operation_to_transfer_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::transfer_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_transfer_to_savings_operation );
  Datum operation_to_transfer_to_savings_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::transfer_to_savings_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_transfer_to_vesting_operation );
  Datum operation_to_transfer_to_vesting_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::transfer_to_vesting_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_withdraw_vesting_operation );
  Datum operation_to_withdraw_vesting_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::withdraw_vesting_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_witness_update_operation );
  Datum operation_to_witness_update_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::witness_update_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_create_proposal_operation );
  Datum operation_to_create_proposal_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::create_proposal_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_proposal_pay_operation );
  Datum operation_to_proposal_pay_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::proposal_pay_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_remove_proposal_operation );
  Datum operation_to_remove_proposal_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::remove_proposal_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_update_proposal_operation );
  Datum operation_to_update_proposal_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::update_proposal_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_update_proposal_votes_operation );
  Datum operation_to_update_proposal_votes_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::update_proposal_votes_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_account_created_operation );
  Datum operation_to_account_created_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::account_created_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_author_reward_operation );
  Datum operation_to_author_reward_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::author_reward_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_changed_recovery_account_operation );
  Datum operation_to_changed_recovery_account_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::changed_recovery_account_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_clear_null_account_balance_operation );
  Datum operation_to_clear_null_account_balance_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::clear_null_account_balance_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_comment_benefactor_reward_operation );
  Datum operation_to_comment_benefactor_reward_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::comment_benefactor_reward_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_comment_payout_update_operation );
  Datum operation_to_comment_payout_update_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::comment_payout_update_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_comment_reward_operation );
  Datum operation_to_comment_reward_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::comment_reward_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_consolidate_treasury_balance_operation );
  Datum operation_to_consolidate_treasury_balance_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::consolidate_treasury_balance_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_curation_reward_operation );
  Datum operation_to_curation_reward_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::curation_reward_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_delayed_voting_operation );
  Datum operation_to_delayed_voting_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::delayed_voting_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_effective_comment_vote_operation );
  Datum operation_to_effective_comment_vote_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::effective_comment_vote_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_expired_account_notification_operation );
  Datum operation_to_expired_account_notification_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::expired_account_notification_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_failed_recurrent_transfer_operation );
  Datum operation_to_failed_recurrent_transfer_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::failed_recurrent_transfer_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_fill_collateralized_convert_request_operation );
  Datum operation_to_fill_collateralized_convert_request_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::fill_collateralized_convert_request_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_fill_convert_request_operation );
  Datum operation_to_fill_convert_request_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::fill_convert_request_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_fill_order_operation );
  Datum operation_to_fill_order_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::fill_order_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_fill_recurrent_transfer_operation );
  Datum operation_to_fill_recurrent_transfer_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::fill_recurrent_transfer_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_fill_transfer_from_savings_operation );
  Datum operation_to_fill_transfer_from_savings_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::fill_transfer_from_savings_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_fill_vesting_withdraw_operation );
  Datum operation_to_fill_vesting_withdraw_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::fill_vesting_withdraw_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_hardfork_hive_operation );
  Datum operation_to_hardfork_hive_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::hardfork_hive_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_hardfork_hive_restore_operation );
  Datum operation_to_hardfork_hive_restore_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::hardfork_hive_restore_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_hardfork_operation );
  Datum operation_to_hardfork_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::hardfork_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_ineffective_delete_comment_operation );
  Datum operation_to_ineffective_delete_comment_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::ineffective_delete_comment_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_interest_operation );
  Datum operation_to_interest_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::interest_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_limit_order_cancelled_operation );
  Datum operation_to_limit_order_cancelled_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::limit_order_cancelled_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_liquidity_reward_operation );
  Datum operation_to_liquidity_reward_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::liquidity_reward_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_pow_reward_operation );
  Datum operation_to_pow_reward_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::pow_reward_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_producer_reward_operation );
  Datum operation_to_producer_reward_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::producer_reward_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_return_vesting_delegation_operation );
  Datum operation_to_return_vesting_delegation_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::return_vesting_delegation_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_shutdown_witness_operation );
  Datum operation_to_shutdown_witness_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::shutdown_witness_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_system_warning_operation );
  Datum operation_to_system_warning_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::system_warning_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_transfer_to_vesting_completed_operation );
  Datum operation_to_transfer_to_vesting_completed_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::transfer_to_vesting_completed_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_vesting_shares_split_operation );
  Datum operation_to_vesting_shares_split_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::vesting_shares_split_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_witness_block_approve_operation );
  Datum operation_to_witness_block_approve_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::witness_block_approve_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_dhf_funding_operation );
  Datum operation_to_dhf_funding_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::dhf_funding_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_dhf_conversion_operation );
  Datum operation_to_dhf_conversion_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::dhf_conversion_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_producer_missed_operation );
  Datum operation_to_producer_missed_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::producer_missed_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_proposal_fee_operation );
  Datum operation_to_proposal_fee_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::proposal_fee_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_collateralized_convert_immediate_conversion_operation );
  Datum operation_to_collateralized_convert_immediate_conversion_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::collateralized_convert_immediate_conversion_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_escrow_approved_operation );
  Datum operation_to_escrow_approved_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::escrow_approved_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_escrow_rejected_operation );
  Datum operation_to_escrow_rejected_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::escrow_rejected_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_proxy_cleared_operation );
  Datum operation_to_proxy_cleared_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::proxy_cleared_operation>(op);
  }

  PG_FUNCTION_INFO_V1( operation_to_declined_voting_rights_operation );
  Datum operation_to_declined_voting_rights_operation( PG_FUNCTION_ARGS )
  {
    _operation* op = PG_GETARG_HIVE_OPERATION_PP( 0 );
    return operation_to<hive::protocol::declined_voting_rights_operation>(op);
  }
}
