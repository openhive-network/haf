extern "C"
{
#include <include/psql_utils/postgres_includes.hpp>
#include <catalog/pg_type.h>
}

#undef elog

#include <fc/io/raw.hpp>

#include "jsonb.hpp"

namespace {

JsonbValue* push_variant_object_to_jsonb(const fc::variant_object& o, JsonbParseState** parseState);
JsonbValue* push_variant_array_to_jsonb(const fc::variants& arr, JsonbParseState** parseState);

void to_numeric(JsonbValue* jb, const fc::variant& value)
{
  jb->type = jbvNumeric;
  // Call the builtin Postgres function that converts text to numeric type.
  jb->val.numeric = DatumGetNumeric(DirectFunctionCall3(numeric_in,
      CStringGetDatum(value.as_string().c_str()),
      ObjectIdGetDatum(InvalidOid), // not used
      Int32GetDatum(-1))); // default type modifier
}

void to_text(JsonbValue* jb, const fc::variant& value)
{
  const auto str = value.as_string();
  jb->type = jbvString;
  jb->val.string.len = str.length();
  jb->val.string.val = pstrdup(str.c_str());
}

JsonbValue* push_variant_value_to_jsonb(const fc::variant& value, JsonbIteratorToken token, JsonbParseState** parseState)
{
  JsonbValue jb;
  switch (value.get_type())
  {
    case fc::variant::null_type:
      jb.type = jbvNull;
      break;
    case fc::variant::uint64_type:
      // Numeric types are converted either to numeric or string types in json.
      // If value can be represented in 32bits, it's converted to numeric type.
      // Otherwise it's converted to string type.
      // This makes the operation::jsonb conversion in sync with the operation::text::jsonb conversion.
      if (value.as_uint64() <= 0xffffffff)
      {
        to_numeric(&jb, value);
      }
      else
      {
        to_text(&jb, value);
      }
      break;
    case fc::variant::int64_type:
      if (value.as_int64() <= 0xffffffff)
      {
        to_numeric(&jb, value);
      }
      else
      {
        to_text(&jb, value);
      }
      break;
    case fc::variant::double_type:
      to_text(&jb, value);
      break;
    case fc::variant::bool_type:
      jb.type = jbvBool;
      jb.val.boolean = value.as_bool();
      break;
    case fc::variant::string_type:
      jb.type = jbvString;
      jb.val.string.len = value.as_string().length();
      jb.val.string.val = pstrdup(value.as_string().c_str());
      break;
    case fc::variant::array_type:
      return push_variant_array_to_jsonb(value.get_array(), parseState);
    case fc::variant::object_type:
      return push_variant_object_to_jsonb(value.get_object(), parseState);
    case fc::variant::blob_type:
      throw std::runtime_error("Converting blob to jsonb is not supported at that time");
  }
  return pushJsonbValue(parseState, token, &jb);
}

JsonbValue* push_variant_array_to_jsonb(const fc::variants& arr, JsonbParseState** parseState)
{
  pushJsonbValue(parseState, WJB_BEGIN_ARRAY, NULL);
  for (const auto& value : arr)
  {
    push_variant_value_to_jsonb(value, WJB_ELEM, parseState);
  }
  return pushJsonbValue(parseState, WJB_END_ARRAY, NULL);
}

JsonbValue* push_object_key_to_jsonb(const std::string& key, JsonbParseState** parseState)
{
  const char* str = key.c_str();
  const auto len = key.length();
  JsonbValue jb;
  jb.type = jbvString;
  jb.val.string.len = len;
  jb.val.string.val = pstrdup(str);
  return pushJsonbValue(parseState, WJB_KEY, &jb);
}

JsonbValue* push_variant_object_to_jsonb(const fc::variant_object& o, JsonbParseState** parseState)
{
  pushJsonbValue(parseState, WJB_BEGIN_OBJECT, NULL);
  for (const auto& entry : o)
  {
    // add key
    push_object_key_to_jsonb(entry.key(), parseState);
    // add value
    push_variant_value_to_jsonb(entry.value(), WJB_VALUE, parseState);
  }
  return pushJsonbValue(parseState, WJB_END_OBJECT, NULL);
}

}

JsonbValue* variant_to_jsonb_value(const fc::variant& value)
{
  JsonbParseState* parseState = {};

  switch (value.get_type())
  {
    case fc::variant::array_type:
      return push_variant_array_to_jsonb(value.get_array(), &parseState);

    case fc::variant::object_type:
      return push_variant_object_to_jsonb(value.get_object(), &parseState);

    default:
      FC_THROW_EXCEPTION( fc::invalid_arg_exception, "Cannot convert variant of type ${type} to jsonb", ("type", value.get_type() ) );
  }
}
